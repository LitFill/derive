module app/cli

import app/derive

//========================================
// Utilities
//========================================

inline fun list/elem(x : a, xs : list<a>, ?(==) : (a, a) -> e bool) : e bool
  with e <- xs.any
  e == x

//========================================
// Flags
//========================================

pub struct myflags
  verbosity  : int              = 0
  version    : bool             = False
  help       : bool             = False
  dry-run    : bool             = False
  input      : string           = ""
  output     : string           = ""
  derivables : list<derivable>  = []

fun myflags/show(m : myflags)
  "Myflags("
  ++ "verbosity=" ++ m.verbosity.int/show ++ ", "
  ++ "version="   ++ m.version.bool/show  ++ ", "
  ++ "help="      ++ m.help.bool/show     ++ ", "
  ++ "dry-run="   ++ m.dry-run.bool/show  ++ ", "
  ++ "input="     ++ m.input.string/show  ++ ", "
  ++ "output="    ++ m.output.string/show ++ ", "
  ++ "derivables=" ++ derivables-show(m.derivables)
  ++ ")"

// HACK: Manual flag parsing
// TODO: Use a more robust flag parsing library (or write it)
// but I'm quite proud of it
//       Currently supports: --verbose/-V[=N], --quiet/-q, --help/-h,
//       --version/-v, --dry-run/-r, -o/--output, -i/--input,
//       --derivable/-d/--deriving/--class/-c (repeatable, comma-separated)
pub fun parse-args(args : list<string>) : _ myflags
  var f := Myflags()
  fun loop(xs : list<string>) : _ ()
    match xs
      Cons(flag, rest)
        | flag.elem(["--verbose", "-V"]) ->
          f := f(verbosity=1)
          loop(rest)
        | flag.elem(["--quiet", "-q"]) ->
          f := f(verbosity=0)
          loop(rest)
        | flag.starts-with("--verbose=").is-just || flag.starts-with("-V=").is-just ->
          match flag.split("=", 2)
            Cons(_, Cons(l, _)) ->
              f := f(verbosity=max(1, l.trim.parse-int.default(1)))
              loop(rest)
            _ -> loop(rest)
        | "--help help -h -?".contains(flag) ->
          f := f(help=True)
        | flag.elem(["version", "--version", "-v"]) ->
          f := f(version=True)
        | flag.elem(["--dry-run", "-r"]) ->
          f := f(dry-run=True)
          loop(rest)
      Cons(flag, Cons(arg, rest))
        | flag.elem(["-o", "--output"]) ->
          f := f(output=arg)
          loop(rest)
        | flag.elem(["-i", "--input"]) ->
          f := f(input=arg)
          loop(rest)
        | flag.elem(["--derivable", "--deriving", "-d", "--class", "-c"]) ->
          f := f(derivables=parse-derivables(f.derivables, arg.split(",")))
          loop(rest)
        | flag.elem(["-V", "--verbose"]) ->
          val level = match arg.parse-int
              Just(l) -> l
              Nothing -> throw("invalid verbosity level: " ++ arg)
          f := f(verbosity=level)
          loop(rest)
      Cons(arg, rest)
        | arg.starts-with("-").is-just.not ->
          f := f(input=arg)
          if f.output.is-empty then
            f := f(output=arg)
          loop(rest)
      Cons(unknown, _) ->
        throw("unknown option: " ++ unknown)
      Nil -> ()
  loop(args)
  f

pub fun derivables-show(ds : list<derivable>) : string
  "[" ++ ds.map(_.derivable/show).join(", ") ++ "]"

fun parse-derivable(s : string) : maybe<derivable>
  match s.to-lower
    "show" -> Just(Show)
    "eq"   -> Just(Eq)
    _      -> Nothing

fun parse-derivables(acc : list<derivable>, parts : list<string>) : exn list<derivable>
  match parts
    Cons(part, rest) ->
      val s = part.trim
      match s.parse-derivable
        Just(x) -> parse-derivables(Cons(x, acc), rest)
        Nothing -> throw("unknown derivable: " ++ s)
    Nil -> acc.reverse

//========================================
// Verbose logging effect
//========================================

pub effect verbose-logging
  fun log-v(level : int, msg : string) : ()

pub fun log-info(msg)  log-v(1, "[ info  ] " ++ msg)
pub fun log-debug(msg) log-v(2, "[ debug ] " ++ msg)
pub fun log-error(msg) log-v(0, "[ error ] " ++ msg)

// level: 0 = errors only, 1 = info, 2 = debug, 3 = trace
pub fun verbose-logging(level : int, action : () -> <console,verbose-logging|e> ()) : <console|e> ()
  with fun log-v(lvl, msg)
    if lvl <= level then msg.println
  action()
