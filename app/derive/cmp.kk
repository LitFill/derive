module app/derive/cmp

import app/derive/ast

import util

//========================================
// Ord deriving
//========================================
// Derives `type-name/cmp(t1, t2) : order` and the operator
// `type-name/(<=>)`.  `order` is Koka's built-in `Lt | Eq | Gt`.
//
// Struct fields are compared left to right, short-circuiting on the first
// non-Eq result.  Type constructors are ordered by declaration order:
// a value of an earlier-declared constructor is Lt a value of a later one.

fun cmp-header(nm : string, tvs : list<string>) : string
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_cmp"
  val arg1 = short-name ++ "_1"
  val arg2 = short-name ++ "_2"
  val type-name = nm.Ty(tvs.map(Ty(_, []))).to-name
  val constraints =
    if tvs.is-empty then "" else
      ", " ++ tvs.map("?%1/cmp : (%1, %1) -> order"%^[_]).join(", ")

  "pub fun %1/cmp(%2 : %3, %4 : %3%5)\n"%^[
    nm, arg1,
    type-name, arg2,
    constraints
  ]

fun cmp-op-header(nm : string, tvs : list<string>) : string
  val type-name = nm.Ty(tvs.map(Ty(_, []))).to-name
  val constraints =
    if tvs.is-empty then "" else
      ", " ++ tvs.map("?%1/cmp : (%1, %1) -> order"%^[_]).join(", ")

  "pub fun %1/(<=>)(x : %2, y : %2%3)\n"%^[nm, type-name, constraints]

// One field comparison: `Type/cmp(x, y)`.  For a typevar `a` this resolves
// via the `?a/cmp` constraint; for a concrete type it calls that type's cmp.
// `x` and `y` are the already-built variable references for the field.
fun field-cmp(nm : string, x : string, y : string, fty : ty) : string
  val ty-name = if fty.name == nm then nm else fty.name
  "%1/cmp(%2, %3)"%^[ty-name, x, y]

// Wrap a comparison so that only Eq falls through to `rest`.
// `rest` may be multi-line (a nested match); its continuation lines are
// indented by `pad` so they align under the `Eq ->` arm.
fun short-circuit(cmp-expr : string, rest : string, pad : string) : string
  val rest' =
    match rest.lines
      Cons(_, Nil) -> rest
      Nil -> rest
      Cons(first, rest-lines) ->
        first ++ "\n" ++
        rest-lines.map(pad ++_).join("\n")
  "match %1\n%2Lt -> Lt\n%2Gt -> Gt\n%2Eq -> %3"%^[cmp-expr, pad, rest']

// Fold a list of field comparisons, short-circuiting on non-Eq.
// `ref` maps a field and its 1-based index to the (x, y) variable references.
// `pad` is the indent for this level's match arms.
fun chain-fields(nm : string, fs : list<field>, start-ix : int, pad : string,
                 ref : (int, field) -> (string, string)) : string
  match fs
    Nil -> "Eq"
    Cons(f, Nil) ->
      val (x, y) = ref(start-ix, f)
      field-cmp(nm, x, y, f.ty)
    Cons(f1, rest) ->
      val (x1, y1) = ref(start-ix, f1)
      val rest' = chain-fields(nm, rest, start-ix + 1, pad ++ "    ", ref)
      short-circuit(field-cmp(nm, x1, y1, f1.ty), rest', pad)

// Reference builders for the two calling conventions.

// Type constructor: positional binding `arg1 ++ ix`.
fun pos-ref(arg1 : string, arg2 : string) : ((int, field) -> (string, string))
  fn(ix, _) (arg1 ++ ix.show, arg2 ++ ix.show)

// Struct: field-name access `arg1 ++ "." ++ name`.
fun field-ref(arg1 : string, arg2 : string) : ((int, field) -> (string, string))
  fn(_, f) (arg1 ++ "." ++ f.name, arg2 ++ "." ++ f.name)

pub fun type-data/cmp/derive(Type-data(nm, tvs, tcs))
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_cmp"
  val arg1 = short-name ++ "_1"
  val arg2 = short-name ++ "_2"
  val header = cmp-header(nm, tvs)
  val op-header = cmp-op-header(nm, tvs)

  // One match arm: same-constructor comparison plus the Lt arms for every
  // later-declared constructor.  Earlier constructors are handled by the
  // previous arm's cross arms, so only forward comparisons are needed here.
  fun make-branch(ix : int, c : type-con) : string
    val args = c.type-con/args
    val n = args.length
    val xs = if n == 0 then "" else list(1, n).map(fn(i) arg1 ++ i.show).join(", ")
    val ys = if n == 0 then "" else list(1, n).map(fn(i) arg2 ++ i.show).join(", ")
    val same-pat =
      if n == 0
        then "(%1, %1)"%^[c.name]
        else "(%1(%2), %1(%3))"%^[c.name, xs, ys]
    val same-arm = "    " ++ same-pat ++ " -> " ++ chain-fields(nm, args, 1, "        ", pos-ref(arg1, arg2))
    // Cross arms: (Ctor_i(...), Ctor_j(...)) -> Lt for every j > i.
    // Ctor_j's fields are bound fresh in the pattern (only arity matters).
    val cross-arms = tcs.drop(ix + 1).map(fn(other)
      val on = other.name
      val other-n = other.type-con/args.length
      val xn = if n == 0 then c.name else c.name ++ "(%1)"%^[xs]
      val yn =
        if other-n == 0 then on
        else on ++ "(" ++ list(1, other-n).map(fn(i) arg2 ++ i.show).join(", ") ++ ")"
      "    (%1, %2) -> Lt"%^[xn, yn]
    ).join("\n")
    if cross-arms.is-empty then same-arm
    else same-arm ++ "\n" ++ cross-arms

  val arms = tcs.map-indexed(fn(ix, c) make-branch(ix, c)).join("\n")
  "%1  match (%2, %3)\n%4\n\n%5  %6/cmp(x, y)"%^[
    header,
    arg1, arg2,
    arms,
    op-header, nm
  ]

pub fun struct-data/cmp/derive(Struct-data(nm, tvs, fs))
  val short-name' = nm.slice.take(2).string || "x"
  val short-name = short-name' ++ "__derived_cmp"
  val arg1 = short-name ++ "_1"
  val arg2 = short-name ++ "_2"
  val header = cmp-header(nm, tvs)
  val op-header = cmp-op-header(nm, tvs)
  header
  ++ "  " ++ chain-fields(nm, fs, 1, "    ", field-ref(arg1, arg2)) ++ "\n"
  ++ "\n"
  ++ op-header
  ++ "  %1/cmp(x, y)"%^[nm]
