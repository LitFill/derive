module app/derive/show

import app/derive/ast

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
