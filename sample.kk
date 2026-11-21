module sample

pub type boolean
  Benar
  Salah
  Mungkin

// boolean.derive(show, eq, cmp)

struct vector3
  x : int
  y : int
  v : int

// vector3.derive(show, eq, cmp)

struct nelist<a>
  head : a
  tail : list<a>

// nelist.derive(show, eq, cmp)

type alist<a, b>
  Nil
  Cons(x : tmap<a, b>, xs : alist<a, b>)

// alist.derive(show, eq, cmp)

struct tmap<a, b>
  front : a
  back  : b

// tmap.derive(show, eq, cmp)

struct extra-long-tuple<a, b, c, d, e, f, g, h>
  alice : a
  bob : b
  charlie : c
  daniel : d
  edward : e
  frank : f
  gordon : g
  henry : h

// extra-long-tuple.derive(show, eq, cmp)

fun bool/dec(lf, rg, ?cond)
  if cond then lf else rg

fun bool/(#)(lf, rg, ?cond) bool/dec(lf, rg, cond)

fun cek-dec()
  val cond = 1 > 0
  "True" # "False"

pub value struct newtype(value : int)

// newtype.derive(show, eq, cmp)
