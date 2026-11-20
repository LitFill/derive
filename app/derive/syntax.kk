module app/derive/syntax

import std/text/parse

import app/derive/ast

//========================================
// Parsers
//========================================

// Daftar kata kunci yang tidak boleh dijadikan nama variabel/modul/fungsi
val keywords = [ "pub", "type", "struct" ]

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

// Optionally consume declaration modifiers (`pub`, `abstract`, `value`).
fun ppub()
  token("pub").ignore

fun pabstract()
  token("abstract").ignore

fun pvalue()
  token("value").ignore

fun pmods()
  optional((), ppub)
  optional((), pabstract)
  optional((), pvalue)

// True at a top-level field separator inside a parenthesized field list.
fun is-field-sep(c : char) : bool
  c == ',' || c == ')'

// True at the end of a line for indentation-style field lists.
fun is-line-end(c : char) : bool
  c == '\n' || c == '\r'

// Does the remaining input start with `s`?
fun peek-string(s : string)
  current-input().string.starts-with(s).is-just

// Consume a string literal body (the opening quote is already consumed).
fun skip-string()
  match current-input().next
    Nothing -> ()
    Just((c, rest)) ->
      satisfy(fn(_ : sslice) Just((c, rest)))
      if c == '\\' then
        match current-input().next
          Nothing -> ()
          Just((c2, rest2)) ->
            satisfy(fn(_ : sslice) Just((c2, rest2)))
            skip-string()
      elif c == '"' then
        ()
      else
        skip-string()

// Consume a character literal body (the opening quote is already consumed).
fun skip-char()
  match current-input().next
    Nothing -> ()
    Just((c, rest)) ->
      satisfy(fn(_ : sslice) Just((c, rest)))
      if c == '\\' then
        match current-input().next
          Nothing -> ()
          Just((c2, rest2)) ->
            satisfy(fn(_ : sslice) Just((c2, rest2)))
            skip-char()
      elif c == '\'' then
        ()
      else
        skip-char()

// Consume a default value up to a top-level `stop` character (or EOL/EOF).
// Delimiters and literals are skipped so separators inside them do not count.
fun skip-default(stop : (char) -> bool, depth : int)
  match current-input().next
    Nothing -> ()
    Just((c, rest)) ->
      if depth == 0 && stop(c) then
        ()
      else
        satisfy(fn(_ : sslice) Just((c, rest)))
        if c == '"' then
          skip-string()
        elif c == '\'' then
          skip-char()
        val depth' =
          if c == '(' || c == '[' || c == '{' then
            depth + 1
          else if c == ')' || c == ']' || c == '}' then
            if depth > 0 then depth - 1 else depth
          else
            depth
        skip-default(stop, depth')

// Consume a balanced `<...>` (the opening `<` is already consumed).
fun skip-angle-acc(depth : int)
  match current-input().next
    Nothing -> ()
    Just((c, rest)) ->
      satisfy(fn(_ : sslice) Just((c, rest)))
      if c == '<' then
        skip-angle-acc(depth + 1)
      elif c == '>' then
        if depth == 1 then lex/ws() else skip-angle-acc(depth - 1)
      else
        skip-angle-acc(depth)

fun skip-angle()
  token("<")
  skip-angle-acc(1)

// Parse a type expression, including function and tuple types.
fun pty()
  val atom = pty-atom()
  if peek-string("->") then
    token("->")
    if peek-string("<") then skip-angle()
    pty()
    Ty("", [])
  else
    atom

fun pty-atom()
  if peek-string("(") then
    token("(")
    val tys = pty.sep-by { token(",") }
    token(")")
    match tys
      Cons(t, Nil) -> t
      _ -> Ty("", [])
  else
    val name = name-p()
    val tyargs1 = [].optional
      token("<")
      val args = pty.sep-by { token(",") }
      token(">")
      args
    val tyargs2 = [].optional
      token("(")
      val args = pty.sep-by { token(",") }
      token(")")
      if args.is-empty then [Ty("", [])] else args
    val tyargs = tyargs1 ++ tyargs2
    mk-ty()

// Parse a field; default values are consumed and discarded (irrelevant for
// deriving show/eq).
fun pfield(stop : (char) -> bool)
  val name = name-p()
  token(":")
  val ty = pty()
  if peek-string("=") then
    token("=")
    skip-default(stop, 0)
    lex/ws()
  mk-field()

fun pfield-comma()
  pfield(is-field-sep)

fun pfield-line()
  pfield(is-line-end)

pub fun ptype()
  pmods()
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
      val args = pfield-comma.sep-by
          token(",")
      token(")")
      args
  mk-type-con()

pub fun pstruct()
  pmods()
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
  val fields = pparamfield || ({many(pfield-line)})
  mk-struct-data()

fun pparamfield()
  with lexeme
  token("(")
  val fs =
      with pfield-comma.sep-by
      token(",")
  token(")")
  fs

pub fun run(p, s)
  s.slice.parse-eof(fn() { val x = p(); lex/ws(); x }).either
