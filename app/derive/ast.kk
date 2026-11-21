//========================================
// Derivable kinds
//========================================

import util

pub type derivable
  Show
  Eq
  Cmp

pub val all-derivables : list<derivable> = [Show, Eq, Cmp]

pub fun derivable/show(d : derivable) : string
  match d
    Show -> "Show"
    Eq   -> "Eq"
    Cmp  -> "Cmp"

pub fun derivable/name(d : derivable) : string
  match d
    Show -> "show"
    Eq   -> "eq"
    Cmp  -> "cmp"

//========================================
// Simple ASTs
//========================================

pub struct ty
  name   : string
  tyargs : list<ty>

pub fun mk-ty(?name, ?tyargs)
  Ty(name, tyargs)

pub fun ty/show(Ty(nm : string, tvs : list<ty>)) : div string
  "Ty(name=%1, tyvars=%2)"%^[nm.string/show, tvs.show(_.ty/show)]

pub fun ty/to-name(t : ty) : string
  ty-list/to-name([t], ", ")

// Format a list of types, recursively; structural recursion keeps this total.
fun ty-list/to-name(ts : list<ty>, sep : string) : string
  match ts
    Nil -> ""
    Cons(Ty(nm, args), rest) ->
      val args' = if args.is-empty then "" else "<" ++ ty-list/to-name(args, ", ") ++ ">"
      nm ++ args' ++ (if rest.is-empty then "" else sep ++ ty-list/to-name(rest, sep))

pub struct field
  name : string
  ty   : ty

pub fun mk-field(?name, ?ty)
  Field(name, ty)

pub fun field/show(Field(nm : string, t : ty))
  "Field(name=%1, ty=%2)"%^[nm.string/show, t.ty/show]

pub struct type-con
  name : string
  args : list<field>

pub fun mk-type-con(?name, ?args)
  Type-con(name, args)

pub fun type-con/show(Type-con(nm : string, args : list<field>)) : div string
  "Type-con(name=%1, args=%2)"%^[nm.string/show, args.show(_.field/show)]

pub struct type-data
  name      : string
  tyvars    : list<string>
  type-cons : list<type-con>

pub fun mk-type-data(?name, ?tyargs, ?tycons)
  Type-data(name, tyargs, tycons)

pub fun type-data/show(Type-data(nm, tvs, tcs))
  "Type-data(name=%1, tyvars=%2, type-cons=%3)"%^[nm.show, tvs.show, tcs.show]

pub struct struct-data
  name   : string
  tyvars : list<string>
  fields : list<field>

pub fun mk-struct-data(?name, ?tyargs, ?fields)
  Struct-data(name, tyargs, fields)

pub fun struct-data/show(Struct-data(nm : string, tvs : list<string>, fs : list<field>)) : div string
  "Struct-data(name=%1, tyvars=%2, fields=%3)"%^[
    nm.string/show,
    tvs.show(_.string/show),
    fs.show(_.field/show)
  ]

//========================================
// DSLs
//========================================

pub fun mk-type-rank1(nm, cons)
  nm.Type-data([], cons)

pub fun nullary/ty-con(nm) nm.Type-con([])
pub fun unary/ty-con(nm, arg) nm.Type-con([arg])
pub fun binary/ty-con(nm, arg1, arg2) nm.Type-con([arg1, arg2])
