module app/derive/eq

import app/derive/ast

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
