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

// Optionally consume a `pub` visibility modifier (e.g. `pub type x ...`)
fun ppub()
  token("pub").ignore

// Optionally consume a `value` modifier (e.g. `pub value struct x ...`)
fun pvalue()
  token("value").ignore

pub fun ptype()
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

pub fun pstruct()
  optional((), ppub)
  optional((), pvalue)
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
  val fields = pparamfield || ({many(pfield)})
  mk-struct-data()

fun pparamfield()
  with lexeme
  token("(")
  val fs =
      with pfield.sep-by
      token(",")
  token(")")
  fs

pub fun run(p, s)
  s.slice.parse(p).either
