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

fun ptype()
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
  Derive-line(line : int, name : string, derivable : derivable)
  Other(content : string)

pub fun has-prefix(s : string, p : string) : bool
  s.list.length >= p.list.length &&
  s.list.take(p.list.length) == p.list

fun try-derive(line : string, markers : list<(string, derivable)>) : maybe2<string, derivable>
  match markers
    Nil -> Nothing2
    Cons((sep, d), rest) ->
      match line.split(sep=sep)
        Cons(part, Cons(_, Nil)) -> Just2(part.list.drop(2).string.trim, d)
        _ -> try-derive(line, rest)

fun to-sep(ks : list<derivable>)
  with k <- ks.map
  val sep = ".derive(" ++ k.name ++ ")"
  (sep, k)

pub fun extract-derive-info(line : string) : (string, derivable)
  match try-derive(line, [Show, Eq].to-sep)
    Just2(name, d) -> (name, d)
    Nothing2 -> ("", Show)

pub fun extract-derive-info'(line : string) : (string, derivable)
  match line.split(sep=".derive(show)")
    Cons(part, Cons(_, Nil)) -> (part.list.drop(2).string.trim, Show)
    _ ->
      match line.split(sep=".derive(eq)")
        Cons(part, Cons(_, Nil)) -> (part.list.drop(2).string.trim, Eq)
        _ -> ("", Show)

pub fun has-derive(line : string) : maybe<derivable>
  if line.find(".derive(show)").is-just then Just(Show)
  elif line.find(".derive(eq)").is-just then Just(Eq)
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
      val is-type        = line.has-prefix("type ")
      val is-struct      = line.has-prefix("struct ") && !is-type
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
        val (name, derivable) = extract-derive-info(line)
        scan-lines(lines, i + 1, Cons(Derive-line(i, name, derivable), acc))
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

pub fun match-derive(defs : list<definition>)
  var last-td := Nothing
  var last-sd := Nothing
  var last-block := ""
  with d <- defs.map
  match d
    Type-def(td, block) ->
      last-td := Just(td)
      last-sd := Nothing
      last-block := block
      d
    Struct-def(sd, block) ->
      last-td := Nothing
      last-sd := Just(sd)
      last-block := block
      d
    Derive-line(ix, nm, derivable) ->
      match last-td
        Just(td) | td.name == nm ->
          match derivable
            Show -> DerivedTypeDef(td, ix, td.show/derive)
            Eq   -> DerivedTypeDef(td, ix, td.eq/derive)
        _ ->
          match last-sd
            Just(sd) | sd.name == nm ->
              match derivable
                Show -> DerivedStructDef(sd, ix, sd.show/derive)
                Eq   -> DerivedStructDef(sd, ix, sd.eq/derive)
            _ -> Other("// " ++ nm ++ ".derive(" ++ derivable.derivable/name ++ ")")
    other -> other

pub fun reassemble(defs : list<definition>) : string
  with return(lines : list<string>)
    lines.join("").trim ++ "\n"
  with d <- defs.map
  match d
    Type-def(_data, block)                -> block ++ "\n"
    Struct-def(_data, block)              -> block ++ "\n"
    DerivedTypeDef(_data, _after, code)   -> code  ++ "\n"
    DerivedStructDef(_data, _after, code) -> code  ++ "\n"
    Derive-line(_line, _name, _derivable) -> ""
    Other(content)                        -> content ++ "\n"

pub fun process-file(fname : string)
  val defs    = scan-file(fname)
  val matched = match-derive(defs)
  reassemble(matched)
