module app/derive/syntax

import std/text/parse

import util

import app/derive/ast

//========================================
// Parsers
//========================================

// Daftar kata kunci yang tidak boleh dijadikan nama variabel/modul/fungsi
val keywords = [ "pub", "type", "struct" ]

fun is-keyword(s : string) : bool
  with k <- keywords.any
  k == s

// Pastikan nama bukan merupakan bagian dari kata kunci (keywords)
fun name-p ()
  with lex
  val nm = none-of-many1(" \r\t\n\"'()<>,.")
  if nm.is-keyword then
    fail("tidak boleh menggunakan kata kunci sebagai nama: " ++ nm)
  nm

// Optionally consume declaration modifiers (`pub`, `abstract`, `value`).
fun pmods()
  optional(())
    token("pub").ignore
  optional(())
    token("abstract").ignore
  optional(())
    token("value").ignore

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
      satisfy fn(_) Just((c, rest))
      if c == '\\' then
        match current-input().next
          Nothing -> ()
          Just((c2, rest2)) ->
            satisfy(fn(_ : sslice) Just((c2, rest2)))
            skip-string()
      elif c == '"' then ()
      else skip-string()

// Consume a character literal body (the opening quote is already consumed).
fun skip-char()
  match current-input().next
    Nothing -> ()
    Just((c, rest)) ->
      satisfy fn(_) Just((c, rest))
      if c == '\\' then
        match current-input().next
          Nothing -> ()
          Just((c2, rest2)) ->
            satisfy fn(_) Just((c2, rest2))
            skip-char()
      elif c == '\'' then ()
      else skip-char()

// Consume a default value up to a top-level `stop` character (or EOL/EOF).
// Delimiters and literals are skipped so separators inside them do not count.
fun skip-default(stop : (char) -> bool, depth : int)
  match current-input().next
    Nothing -> ()
    Just((c, rest)) ->
      if depth == 0 && stop(c) then ()
      else
        satisfy fn(_) Just((c, rest))
        if c == '"' then
          skip-string()
        elif c == '\'' then
          skip-char()
        val depth' =
          if c == '(' || c == '[' || c == '{' then
            depth + 1
          elif c == ')' || c == ']' || c == '}' then
            if depth > 0 then depth - 1 else depth
          else
            depth
        skip-default(stop, depth')

// Consume a balanced `<...>` (the opening `<` is already consumed).
fun skip-angle-acc(depth : int)
  match current-input().next
    Nothing -> ()
    Just((c, rest)) ->
      satisfy fn(_) Just((c, rest))
      if c == '<' then
        skip-angle-acc(depth + 1)
      elif c == '>' then
        if depth == 1 then whitespace0().ignore else skip-angle-acc(depth - 1)
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

fun comma() token(",")

fun pty-atom()
  if peek-string("(") then
    token("(")
    val tys = pty.sep-by(comma)
    token(")")
    match tys
      Cons(t, Nil) -> t
      _ -> Ty("", [])
  else
    val name = name-p()
    val tyargs1 = [].optional
      token("<")
      val args = pty.sep-by(comma)
      token(">")
      args
    val tyargs2 = [].optional
      token("(")
      val args = pty.sep-by(comma)
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
    whitespace0().ignore
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
      val args = name-p.sep-by(comma)
      token(">")
      args
  val tycons = many(ptycon)
  mk-type-data()

fun ptycon()
  val name = name-p()
  val args = [].optional
      token("(")
      val args = pfield-comma.sep-by(comma)
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
      val args = name-p.sep-by(comma)
      token(">")
      args
  val fields = pparamfield || ({many(pfield-line)})
  mk-struct-data()

fun pparamfield()
  with lex
  token("(")
  val fs = pfield-comma.sep-by(comma)
  token(")")
  fs

pub fun run(p : parser<e, a>, s : string) : e either<string, a>
  with s.parser/run
  val x = p()
  whitespace0()
  eof()
  x

