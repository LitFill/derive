module app/derive

import std/text/parse
import std/os/file
import std/os/path

// TODO: The type inferer marks match-derive as <div>, but it should be total
//       Investigate why mutable variables in with/map cause div inference

//========================================
// Derivable kinds
//========================================

pub type derivable
  Show
  Eq

pub fun derivable/show(d : derivable) : string
  match d
    Show -> "Show"
    Eq -> "Eq"

pub fun derivable/name(d : derivable) : string
  match d
    Show -> "show"
    Eq -> "eq"

//========================================
// Simple ASTs
//========================================

pub struct ty
  name : string
  tyargs : list<ty>

pub fun mk-ty(?name, ?tyargs)
  Ty(name, tyargs)

pub fun ty/show(Ty(nm : string, tvs : list<ty>)) : div string
  "Ty(name="
  ++ nm.string/show
  ++ ", tyvars="
  ++ tvs.list/show(ty/show)
  ++ ")"

pub fun ty/to-name(Ty(nm, args))
  val args' =
    if args.is-empty then "" else
      "<" ++ args.map(to-name).join(", ") ++ ">"
  nm ++ args'

pub struct field
  name : string
  ty : ty

pub fun mk-field(?name, ?ty)
  Field(name, ty)

pub fun field/show(Field(nm : string, t : ty))
  "Field(name="
  ++ nm.string/show
  ++ ", ty="
  ++ t.ty/show
  ++ ")"

pub struct type-con
  name : string
  args : list<field>

pub fun mk-type-con(?name, ?args)
  Type-con(name, args)

pub fun type-con/show(Type-con(nm : string, args : list<field>)) : div string
  "Type-con(name="
  ++ nm.string/show
  ++ ", args="
  ++ args.list/show(field/show)
  ++ ")"

pub struct type-data
  name      : string
  tyvars    : list<string>
  type-cons : list<type-con>

pub fun mk-type-data(?name, ?tyargs, ?tycons)
  Type-data(name, tyargs, tycons)

pub fun type-data/show(Type-data(nm, tvs, tcs))
  "Type-data(name="
  ++ nm.show
  ++ ", tyvars="
  ++ tvs.show
  ++ ", type-cons="
  ++ tcs.show
  ++ ")"

pub struct struct-data
  name   : string
  tyvars : list<string>
  fields : list<field>

pub fun mk-struct-data(?name, ?tyargs, ?fields)
  Struct-data(name, tyargs, fields)

pub fun struct-data/show(Struct-data(nm : string, tvs : list<string>, fs : list<field>)) : div string
  "Struct-data(name="
  ++ nm.string/show
  ++ ", tyvars="
  ++ tvs.list/show(string/show)
  ++ ", fields="
  ++ fs.list/show(field/show)
  ++")"

//========================================
// DSLs
//========================================

pub fun mk-type-rank1(nm, cons)
  nm.Type-data([], cons)

pub fun nullary/ty-con(nm) nm.Type-con([])
pub fun unary/ty-con(nm, arg) nm.Type-con([arg])
pub fun binary/ty-con(nm, arg1, arg2) nm.Type-con([arg1, arg2])

//========================================
// Show deriving
//========================================

fun derive-show-header(nm : string, tvs : list<string>)
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_show"
  val type-name  = nm.Ty(tvs.map(Ty(_, []))).to-name
  val constraints =
    if tvs.is-empty then "" else
      ", " ++ tvs.map(fn(tv) "?" ++ tv ++ "/show : " ++ tv ++ " -> string").join(", ")

  (short-name,
   type-name,
   "pub fun "
   ++ nm ++ "/show("
   ++ short-name ++ " : " ++ type-name
   ++ constraints
   ++ ")\n")

pub fun type-data/show/derive(Type-data(nm, tvs, tcs))
  val (short-name, _, header) = derive-show-header(nm, tvs)
  fun make-arg(args : list<field>)
      if args.is-empty then "" else
        "("
        ++ args.map(fn(Field(n, _)) n ++ "=\" ++ " ++ n ++ ".show").join(" ++ \", ")
        ++ " ++ \")"
  fun make-arg-pat(args : list<field>)
      if args.is-empty then "" else
        "("
        ++ args.map(fn(Field(n, _t)) n).join(", ")
        ++ ")"
  fun make-branch(x : type-con)
    val args    = x.type-con/args
    val arm-lhs = "    " ++ x.type-con/name ++ make-arg-pat(args) ++ " -> "
    val arm-rhs = "\"" ++ x.type-con/name ++ make-arg(args) ++ "\""
    arm-lhs ++ arm-rhs

  header
  ++ "  match " ++ short-name ++ "\n"
  ++ tcs.map(make-branch).join("\n")

pub fun struct-data/show/derive(Struct-data(nm, tvs, fs))
  val (short-name, _, header) = derive-show-header(nm, tvs)
  fun make-field-show(f : field)
      "\""
      ++ f.name     ++ "=\" ++ "
      ++ short-name ++ "." ++ f.name ++ ".show"
  val fields-arg = fs.map(make-field-show).join(" ++ \", \"\n  ++ ")

  header
  ++ "  \""  ++ nm.capitalize ++ "(\"\n"
  ++ "  ++ " ++ fields-arg    ++ "\n"
  ++ "  ++ \")\""

//========================================
// Eq deriving
//========================================

fun derive-eq-header(nm : string, tvs : list<string>)
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_eq"
  val arg1 = short-name ++ "_1"
  val arg2 = short-name ++ "_2"
  val type-name = nm.Ty(tvs.map(Ty(_, []))).to-name
  val constraints =
    if tvs.is-empty then "" else
      ", " ++ tvs.map(fn(tv) "?" ++ tv ++ "/(==) : (" ++ tv ++ ", " ++ tv ++ ") -> bool").join(", ")
  "pub fun " ++ nm ++ "/eq("
  ++ arg1 ++ " : " ++ type-name ++ ", "
  ++ arg2 ++ " : " ++ type-name
  ++ constraints ++ ")\n"

fun derive-eq-op-header(nm : string, tvs : list<string>)
  val type-name = nm.Ty(tvs.map(Ty(_, []))).to-name
  val constraints =
    if tvs.is-empty then "" else
      ", " ++ tvs.map(fn(tv) "?" ++ tv ++ "/(==) : (" ++ tv ++ ", " ++ tv ++ ") -> bool").join(", ")
  "pub fun " ++ nm ++ "/(==)(x : " ++ type-name ++ ", y : " ++ type-name ++ constraints ++ ")\n"

pub fun type-data/eq/derive(Type-data(nm, tvs, tcs))
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_eq"
  val arg1 = short-name ++ "_1"
  val arg2 = short-name ++ "_2"
  val header = derive-eq-header(nm, tvs)
  val op-header = derive-eq-op-header(nm, tvs)
  fun make-var-list(n : int, pre : string) : string
    if n == 0 then "" else
      range/list(1, n).map(fn(i) pre ++ i.show).join(", ")
  fun var-cmp(i : int, field-ty : ty) : string
    val xi = arg1 ++ i.show
    val yi = arg2 ++ i.show
    // Self-referential field: use the generated eq function
    if field-ty.name == nm
      then nm ++ "/eq(" ++ xi ++ ", " ++ yi ++ ")"
      else xi ++ " == " ++ yi
  fun make-var-cmp(n : int, args : list<field>) : string
    if n == 0 then "True" else
      args.map-indexed(fn(ix, Field(_, fty)) var-cmp(ix + 1, fty)).join(" && ")
  fun make-branch(c : type-con)
    val args = c.type-con/args
    val n = args.length
    val xs = make-var-list(n, arg1)
    val ys = make-var-list(n, arg2)
    val pat = if n == 0
      then "(" ++ c.name ++ ", " ++ c.name ++ ")"
      else "(" ++ c.name ++ "(" ++ xs ++ "), " ++ c.name ++ "(" ++ ys ++ "))"
    val body = make-var-cmp(n, args)
    "    " ++ pat ++ " -> " ++ body

  header
  ++ "  match (" ++ arg1 ++ ", " ++ arg2 ++ ")\n"
  ++ tcs.map(make-branch).join("\n") ++ "\n"
  ++ "    _ -> False\n"
  ++ "\n"
  ++ op-header
  ++ "  " ++ nm ++ "/eq(x, y)"

pub fun struct-data/eq/derive(Struct-data(nm, tvs, fs))
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_eq"
  val arg1 = short-name ++ "_1"
  val arg2 = short-name ++ "_2"
  val header = derive-eq-header(nm, tvs)
  val op-header = derive-eq-op-header(nm, tvs)
  val cmp = fs.map(fn(Field(fn_name, fty))
      // Self-referential field: use the generated eq function
      if fty.name == nm
        then nm ++ "/eq(" ++ arg1 ++ "." ++ fn_name ++ ", " ++ arg2 ++ "." ++ fn_name ++ ")"
        else arg1 ++ "." ++ fn_name ++ " == " ++ arg2 ++ "." ++ fn_name
    ).join("\n  && ")
  val body = cmp || "True"

  header
  ++ "  " ++ body ++ "\n"
  ++ "\n"
  ++ op-header
  ++ "  " ++ nm ++ "/eq(x, y)"

//========================================
// Parsers
//========================================

// Daftar kata kunci yang tidak boleh dijadikan nama variabel/modul/fungsi
val keywords = [ "type", "struct" ]

fun is-keyword(s : string) : bool
  with k <- keywords.any
  k == s

// Konsumsi whitespace (termasuk spasi, tab, dan newline) secara eksplisit
fun whitespace-char()
  [ { char(' ')  }
  , { char('\t') }
  , { char('\n') }
  , { char('\r') }
  ] .choose

fun whitespace-char'()
  with return(xs) xs.choose
  with c <- [' ', '\t', '\n', '\r'].map
  return
    char(c)

pub fun lex/ws()
  many(whitespace-char).ignore

pub fun lex/lexeme(p : () -> <parse|e> a) : <parse|e> a
  val res = p()
  lex/ws()
  res

pub fun lex/token(s :string)
  with lexeme
  pstring(s)

// Pastikan nama bukan merupakan bagian dari kata kunci (keywords)
fun name-p ()
  with lexeme
  val nm = none-of-many1(" \r\t\n\"'()<>,.")
  if nm.is-keyword then
    fail("tidak boleh menggunakan kata kunci sebagai nama: " ++ nm)
  nm

// Optionally consume a `pub` visibility modifier (e.g. `pub type x ...`)
fun ppub()
  token("pub")
  return ()

fun ptype()
  optional((), ppub)
  token("type")
  val name = name-p()
  val tyargs = [].optional
      token("<")
      val args = name-p.sep-by { token(",") }
      token(">")
      args
  val tycons = many(ptycon)
  mk-type-data()

fun ptycon()
  val name = name-p()
  val args = [].optional
      token("(")
      val args = pfield.sep-by
          token(",")
      token(")")
      args
  mk-type-con()

fun pfield()
  val name = name-p()
  token(":")
  val ty = pty()
  mk-field()

fun pty()
  val name = name-p()
  val tyargs =
      with [].optional
      token("<")
      val args =
          with pty.sep-by
          token(",")
      token(">")
      args
  mk-ty()

fun pstruct()
  optional((), ppub)
  token("struct")
  val name = name-p()
  val tyargs =
      with [].optional
      token("<")
      val args =
          with name-p.sep-by
          token(",")
      token(">")
      args
  val fields = many(pfield)
  mk-struct-data()

pub fun run(p, s)
  s.slice.parse(p).either

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
      val is-struct      = (line.has-prefix("struct ") || line.has-prefix("pub struct ")) && !is-type
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
              app/derive/Eq -> [DerivedTypeDef(td, ix, td.eq/derive)]
          _ ->
            match last-sd
              Just(sd) | sd.name == nm ->
                match k
                  Show -> [DerivedStructDef(sd, ix, sd.show/derive)]
                  Eq   -> [DerivedStructDef(sd, ix, sd.eq/derive)]
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
