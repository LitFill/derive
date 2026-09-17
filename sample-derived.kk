module sample

pub type boolean
  Benar
  Salah
  Mungkin

pub fun boolean/show(bo__derived_show : boolean)
  match bo__derived_show
    Benar -> "Benar"
    Salah -> "Salah"
    Mungkin -> "Mungkin"

pub fun boolean/eq(bo__derived_eq_1 : boolean, bo__derived_eq_2 : boolean)
  match (bo__derived_eq_1, bo__derived_eq_2)
    (Benar, Benar) -> True
    (Salah, Salah) -> True
    (Mungkin, Mungkin) -> True
    _ -> False

pub fun boolean/(==)(x : boolean, y : boolean)
  boolean/eq(x, y)

struct vector3
  x : int
  y : int
  v : int

pub fun vector3/show(ve__derived_show : vector3)
  "Vector3("
  ++ "x=" ++ ve__derived_show.x.show ++ ", "
  ++ "y=" ++ ve__derived_show.y.show ++ ", "
  ++ "v=" ++ ve__derived_show.v.show
  ++ ")"

pub fun vector3/eq(ve__derived_eq_1 : vector3, ve__derived_eq_2 : vector3)
  ve__derived_eq_1.x == ve__derived_eq_2.x
  && ve__derived_eq_1.y == ve__derived_eq_2.y
  && ve__derived_eq_1.v == ve__derived_eq_2.v

pub fun vector3/(==)(x : vector3, y : vector3)
  vector3/eq(x, y)

struct nelist<a>
  head : a
  tail : list<a>

pub fun nelist/show(ne__derived_show : nelist<a>, ?a/show : a -> string)
  "Nelist("
  ++ "head=" ++ ne__derived_show.head.show ++ ", "
  ++ "tail=" ++ ne__derived_show.tail.show
  ++ ")"

pub fun nelist/eq(ne__derived_eq_1 : nelist<a>, ne__derived_eq_2 : nelist<a>, ?a/(==) : (a, a) -> bool)
  ne__derived_eq_1.head == ne__derived_eq_2.head
  && ne__derived_eq_1.tail == ne__derived_eq_2.tail

pub fun nelist/(==)(x : nelist<a>, y : nelist<a>, ?a/(==) : (a, a) -> bool)
  nelist/eq(x, y)

type alist<a, b>
  Nil
  Cons(x : tmap<a, b>, xs : alist<a, b>)

pub fun alist/show(al__derived_show : alist<a, b>, ?a/show : a -> string, ?b/show : b -> string)
  match al__derived_show
    Nil -> "Nil"
    Cons(x, xs) -> "Cons(x=" ++ x.show ++ ", xs=" ++ xs.show ++ ")"

pub fun alist/eq(al__derived_eq_1 : alist<a, b>, al__derived_eq_2 : alist<a, b>, ?a/(==) : (a, a) -> bool, ?b/(==) : (b, b) -> bool)
  match (al__derived_eq_1, al__derived_eq_2)
    (Nil, Nil) -> True
    (Cons(al__derived_eq_11, al__derived_eq_12), Cons(al__derived_eq_21, al__derived_eq_22)) -> al__derived_eq_11 == al__derived_eq_21 && alist/eq(al__derived_eq_12, al__derived_eq_22)
    _ -> False

pub fun alist/(==)(x : alist<a, b>, y : alist<a, b>, ?a/(==) : (a, a) -> bool, ?b/(==) : (b, b) -> bool)
  alist/eq(x, y)

struct tmap<a, b>
  front : a
  back  : b

pub fun tmap/show(tm__derived_show : tmap<a, b>, ?a/show : a -> string, ?b/show : b -> string)
  "Tmap("
  ++ "front=" ++ tm__derived_show.front.show ++ ", "
  ++ "back=" ++ tm__derived_show.back.show
  ++ ")"

pub fun tmap/eq(tm__derived_eq_1 : tmap<a, b>, tm__derived_eq_2 : tmap<a, b>, ?a/(==) : (a, a) -> bool, ?b/(==) : (b, b) -> bool)
  tm__derived_eq_1.front == tm__derived_eq_2.front
  && tm__derived_eq_1.back == tm__derived_eq_2.back

pub fun tmap/(==)(x : tmap<a, b>, y : tmap<a, b>, ?a/(==) : (a, a) -> bool, ?b/(==) : (b, b) -> bool)
  tmap/eq(x, y)

struct extra-long-tuple<a, b, c, d, e, f, g, h>
  alice : a
  bob : b
  charlie : c
  daniel : d
  edward : e
  frank : f
  gordon : g
  henry : h

pub fun extra-long-tuple/show(ex__derived_show : extra-long-tuple<a, b, c, d, e, f, g, h>, ?a/show : a -> string, ?b/show : b -> string, ?c/show : c -> string, ?d/show : d -> string, ?e/show : e -> string, ?f/show : f -> string, ?g/show : g -> string, ?h/show : h -> string)
  "Extra-long-tuple("
  ++ "alice=" ++ ex__derived_show.alice.show ++ ", "
  ++ "bob=" ++ ex__derived_show.bob.show ++ ", "
  ++ "charlie=" ++ ex__derived_show.charlie.show ++ ", "
  ++ "daniel=" ++ ex__derived_show.daniel.show ++ ", "
  ++ "edward=" ++ ex__derived_show.edward.show ++ ", "
  ++ "frank=" ++ ex__derived_show.frank.show ++ ", "
  ++ "gordon=" ++ ex__derived_show.gordon.show ++ ", "
  ++ "henry=" ++ ex__derived_show.henry.show
  ++ ")"

pub fun extra-long-tuple/eq(ex__derived_eq_1 : extra-long-tuple<a, b, c, d, e, f, g, h>, ex__derived_eq_2 : extra-long-tuple<a, b, c, d, e, f, g, h>, ?a/(==) : (a, a) -> bool, ?b/(==) : (b, b) -> bool, ?c/(==) : (c, c) -> bool, ?d/(==) : (d, d) -> bool, ?e/(==) : (e, e) -> bool, ?f/(==) : (f, f) -> bool, ?g/(==) : (g, g) -> bool, ?h/(==) : (h, h) -> bool)
  ex__derived_eq_1.alice == ex__derived_eq_2.alice
  && ex__derived_eq_1.bob == ex__derived_eq_2.bob
  && ex__derived_eq_1.charlie == ex__derived_eq_2.charlie
  && ex__derived_eq_1.daniel == ex__derived_eq_2.daniel
  && ex__derived_eq_1.edward == ex__derived_eq_2.edward
  && ex__derived_eq_1.frank == ex__derived_eq_2.frank
  && ex__derived_eq_1.gordon == ex__derived_eq_2.gordon
  && ex__derived_eq_1.henry == ex__derived_eq_2.henry

pub fun extra-long-tuple/(==)(x : extra-long-tuple<a, b, c, d, e, f, g, h>, y : extra-long-tuple<a, b, c, d, e, f, g, h>, ?a/(==) : (a, a) -> bool, ?b/(==) : (b, b) -> bool, ?c/(==) : (c, c) -> bool, ?d/(==) : (d, d) -> bool, ?e/(==) : (e, e) -> bool, ?f/(==) : (f, f) -> bool, ?g/(==) : (g, g) -> bool, ?h/(==) : (h, h) -> bool)
  extra-long-tuple/eq(x, y)

fun bool/dec(lf, rg, ?cond)
  if cond then lf else rg

fun bool/(#)(lf, rg, ?cond) bool/dec(lf, rg, cond)

fun cek-dec()
  val cond = 1 > 0
  "True" # "False"
