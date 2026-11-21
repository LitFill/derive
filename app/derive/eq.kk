module app/derive/eq

import app/derive/ast

import util

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
      ", " ++ tvs.map("?%1/(==) : (%1, %1) -> bool"%^[_]).join(", ")

  "pub fun %1/eq(%2 : %3, %4 : %3%5)\n"%^[
    nm, arg1,
    type-name, arg2,
    constraints
  ]

fun derive-eq-op-header(nm : string, tvs : list<string>)
  val type-name = nm.Ty(tvs.map(Ty(_, []))).to-name
  val constraints =
    if tvs.is-empty then "" else
      ", " ++ tvs.map("?%1/(==) : (%1, %1) -> bool"%^[_]).join(", ")

  "pub fun %1/(==)(x : %2, y : %2%3)\n"%^[ nm, type-name, constraints ]

pub fun type-data/eq/derive(Type-data(nm, tvs, tcs))
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_eq"
  val arg1 = short-name ++ "_1"
  val arg2 = short-name ++ "_2"
  val header = derive-eq-header(nm, tvs)
  val op-header = derive-eq-op-header(nm, tvs)
  fun make-var-list(n : int, pre : string) : string
    if n == 0 then "" else
      list(1, n, fn(i : int) pre ++ i.show).join(", ")
  fun var-cmp(i : int, field-ty : ty) : string
    val xi = arg1 ++ i.show
    val yi = arg2 ++ i.show
    // Self-referential field: use the generated eq function
    if field-ty.name == nm
      then "%1/eq(%2, %3)"%^[nm, xi, yi]
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
      then "(%1, %1)"%^[c.name]
      else "(%1(%2), %1(%3))"%^[c.name, xs, ys]
    val body = make-var-cmp(n, args)
    "    %1 -> %2"%^[pat, body]

  header
  ++ "  match (%1, %2)\n"%^[arg1, arg2]
  ++ tcs.map(make-branch).join("\n") ++ "\n"
  ++ "    _ -> False\n"
  ++ "\n"
  ++ op-header
  ++ "  %1/eq(x, y)"%^[nm]

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
        then "%1/eq(%2.%3, %4.%3)"%^[nm, arg1, fn_name, arg2]
        else "%1.%3 == %2.%3"%^[arg1, arg2, fn_name]
    ).join("\n  && ")
  val body = cmp || "True"

  "%1  %2\n\n%3  %4/eq(x, y)"%^[header, body, op-header, nm]
