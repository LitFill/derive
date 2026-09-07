module sample

pub type boolean
  Benar
  Salah
  Mungkin

// boolean.derive(show)

// boolean.derive(eq)

struct vector3
  x : int
  y : int
  v : int

// vector3.derive(show)

// vector3.derive(eq)

struct nelist<a>
  head : a
  tail : list<a>

// nelist.derive(show)

// nelist.derive(eq)

type alist<a, b>
  Nil
  Cons(x : tmap<a, b>, xs : alist<a, b>)

// alist.derive(show)

// alist.derive(eq)

struct tmap<a, b>
  front : a
  back  : b

// tmap.derive(show)

// tmap.derive(eq)

struct extra-long-tuple<a, b, c, d, e, f, g, h>
  alice : a
  bob : b
  charlie : c
  daniel : d
  edward : e
  frank : f
  gordon : g
  henry : h

// extra-long-tuple.derive(show)

// extra-long-tuple.derive(eq)

fun bool/dec(lf, rg, ?cond)
  if cond then lf else rg

fun bool/(#)(lf, rg, ?cond) bool/dec(lf, rg, cond)

fun cek-dec()
  val cond = 1 > 0
  "True" # "False"
