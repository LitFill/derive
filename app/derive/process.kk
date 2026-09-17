module app/derive/process

import std/os/file
import std/os/path

import app/derive/ast
import app/derive/syntax
import app/derive/show
import app/derive/eq

// TODO: The type inferer marks match-derive as <div>, but it should be total
//       Investigate why mutable variables in with/map cause div inference

//========================================
// Definition processing pipeline
//========================================

pub type definition
  Type-def(data : type-data, block : string)
  Struct-def(data : struct-data, block : string)
  DerivedTypeDef(data : type-data, after-line : int, code : string)
  DerivedStructDef(data : struct-data, after-line : int, code : string)
  Derive-line(line : int, name : string, derivables : list<derivable>, raw-line : string)
  Other(content : string)

pub fun has-prefix(s : string, p : string) : bool
  s.list.length >= p.list.length &&
  s.list.take(p.list.length) == p.list

// Lowercase an ASCII string, so directive kinds can be case-insensitive
fun ascii-lower(s : string) : string
  s.list.map(fn(c) if c >= 'A' && c <= 'Z' then (c.int + 32).char else c).string

fun derivable-of-name(s : string) : maybe<derivable>
  match ascii-lower(s.trim)
    "show" -> Just(Show)
    "eq"   -> Just(Eq)
    _      -> Nothing

pub fun extract-derive-info(line : string) : (string, list<derivable>)
  match line.split(sep=".derive(")
    Cons(part, Cons(rest, Nil)) ->
      val content = match rest.split(sep=")")
        Cons(head, _) -> head
        Nil -> ""
      val ds = content.split(sep=",").filter-map(derivable-of-name)
      (part.list.drop(2).string.trim, ds)
    _ -> ("", [])

// Raw content between `.derive(` and `)`, e.g. "show, eq"
fun derive-raw(line : string) : string
  match line.split(sep=".derive(")
    Cons(_, Cons(rest, Nil)) ->
      match rest.split(sep=")")
        Cons(head, _) -> head
        Nil -> ""
    _ -> ""

pub fun has-derive(line : string) : maybe<list<derivable>>
  if line.find(".derive(").is-just then
    val (_, ds) = extract-derive-info(line)
    if ds.is-empty then Nothing else Just(ds)
  else Nothing

pub fun scan-file(fname : string) : <exn, fsys, div> list<definition>
  val content = read-text-file(fname.path)
  val lines = content.lines
  scan-lines(lines, 0, [])

fun scan-lines(lines : list<string>, i : int, acc : list<definition>) : <exn, fsys, div> list<definition>
  if i >= lines.length then
    return acc.reverse
  match lines[i]
    Nothing -> scan-lines(lines, i + 1, acc)
    Just(line) ->
      val is-type        = line.has-prefix("type ") || line.has-prefix("pub type ")
      val is-struct      = (line.has-prefix("struct ") || line.has-prefix("pub struct ") || line.has-prefix("pub value struct")) && !is-type
      val m-derive       = if line.has-prefix("// ") then line.has-derive else Nothing
      if is-type || is-struct then
        val is-type-block = is-type
        val (block-lines-rev, j) = collect-block(lines, i + 1, [line])
        val block-text = block-lines-rev.reverse.join("\n")
        val new-acc =
            if is-type-block then
              match ptype.run(block-text)
                Right(td : type-data) -> Cons(Type-def(td, block-text), acc)
                Left(_) -> block-lines-rev.foldl(acc) fn(ds, l) Cons(Other(l), ds)
            else
              match pstruct.run(block-text)
                Right(sd : struct-data) -> Cons(Struct-def(sd, block-text), acc)
                Left(_) -> block-lines-rev.foldl(acc) fn(ds, l) Cons(Other(l), ds)
        scan-lines(lines, j, new-acc)
      elif m-derive.is-just then
        match m-derive
          Just(ds) ->
            val (name, _) = extract-derive-info(line)
            scan-lines(lines, i + 1, Cons(Derive-line(i, name, ds, line), acc))
          Nothing -> scan-lines(lines, i + 1, acc)
      else
        scan-lines(lines, i + 1, Cons(Other(line), acc))

fun collect-block(lines : list<string>, start : int, rev-lines : list<string>) : <div> (list<string>, int)
  match lines[start]
    Just(l)
      | l.is-empty ->
        collect-block(lines, start + 1, rev-lines)
      | l.has-prefix("  ") -> // isnt this a bit fragile?
        collect-block(lines, start + 1, Cons(l, rev-lines))
    _ -> (Cons("", rev-lines), start)

// True if the raw kind name must stay in the leftover directive comment:
// unknown kinds always stay; derived kinds are removed.
fun kind-kept(s : string, requested : list<derivable>) : bool
  match derivable-of-name(s)
    Nothing -> True
    Just(d) -> requested.any(fn(c) c.derivable/name == d.derivable/name).not

pub fun match-derive(defs : list<definition>, cli : list<derivable>)
  var last-td := Nothing
  var last-sd := Nothing
  var last-block := ""
  with d <- defs.flatmap
  match d
    Type-def(td, block) ->
      last-td := Just(td)
      last-sd := Nothing
      last-block := block
      [d]
    Struct-def(sd, block) ->
      last-td := Nothing
      last-sd := Just(sd)
      last-block := block
      [d]
    Derive-line(ix, nm, ds, rawline) ->
      val requested =
        if cli.is-empty then ds
        else ds.filter(fn(k) cli.any(fn(c) c.derivable/name == k.derivable/name))
      fun derive1(k)
        match last-td
          Just(td) | td.name == nm ->
            match k
              Show -> [DerivedTypeDef(td, ix, td.show/derive)]
              app/derive/ast/Eq -> [DerivedTypeDef(td, ix, td.eq/derive)]
          _ ->
            match last-sd
              Just(sd) | sd.name == nm ->
                match k
                  Show -> [DerivedStructDef(sd, ix, sd.show/derive)]
                  app/derive/ast/Eq   -> [DerivedStructDef(sd, ix, sd.eq/derive)]
              _ -> []
      val derived = requested.flatmap(derive1)
      val leftover =
        if derived.is-empty then [Other(rawline)]
        else
          val kept = derive-raw(rawline).split(",").map(fn(s) s.trim)
            .filter(fn(s) s.is-empty.not)
            .filter(fn(s) kind-kept(s, requested))
          if kept.is-empty then [] else [Other("// " ++ nm ++ ".derive(" ++ kept.join(", ") ++ ")")]
      leftover ++ derived
    other -> [other]

pub fun reassemble(defs : list<definition>) : string
  fun piece(d : definition, prev-derived : bool) : (string, bool)
    val is-derived = match d
      DerivedTypeDef(_, _, _)    -> True
      DerivedStructDef(_, _, _)  -> True
      _                          -> False
    val s = match d
      Type-def(_data, block)                -> block ++ "\n"
      Struct-def(_data, block)              -> block ++ "\n"
      DerivedTypeDef(_data, _after, code)   -> code  ++ "\n"
      DerivedStructDef(_data, _after, code) -> code  ++ "\n"
      Derive-line(_line, _name, _ds, _rawline)  -> ""
      Other(content)                        -> content ++ "\n"
    ((if is-derived && prev-derived then "\n" else "") ++ s, is-derived)
  val (_, lines) = defs.foldl((False, [])) fn((prev, acc), d)
    val (s, cur) = piece(d, prev)
    (cur, Cons(s, acc))
  lines.reverse.join("").trim ++ "\n"

pub fun process-file(fname : string, cli : list<derivable>)
  val defs    = scan-file(fname)
  val matched = match-derive(defs, cli)
  reassemble(matched)
