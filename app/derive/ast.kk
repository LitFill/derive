//========================================
// Derivable kinds
//========================================

pub type derivable
  Show
  Eq

pub val all-derivables : list<derivable> = [Show, Eq]

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
  name   : string
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
  ty   : ty

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
