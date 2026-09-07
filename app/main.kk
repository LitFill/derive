module app/main

import std/os/file
import std/os/path
import std/os/env
import app/derive

//========================================
// Utilities
//========================================

inline fun bool/fork(cond, a, b) if cond then a else b

inline fun list/elem(x : a, xs : list<a>, ?(==) : (a, a) -> e bool) : e bool
  with e <- xs.any
  e == x

//========================================
// Flags
//========================================

struct myflags
  verbosity  : int              = 0
  version    : bool             = False
  help       : bool             = False
  dry-run    : bool             = False
  input      : string           = ""
  output     : string           = ""
  derivables : list<derivable>  = []

fun derivables-show(ds : list<derivable>) : string
  "[" ++ ds.map(fn(d) d.derivable/show).join(",") ++ "]"

fun parse-derivable(s : string) : maybe<derivable>
  match s.to-lower
    "show" -> Just(Show)
    "eq"   -> Just(Eq)
    _      -> Nothing

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
fun parse-derivables(acc : list<derivable>, parts : list<string>) : exn list<derivable>
  match parts
    Cons(part, rest) ->
      val s = part.trim
      match s.parse-derivable
        Just(x) -> parse-derivables(Cons(x, acc), rest)
        Nothing -> throw("unknown derivable: " ++ s)
    Nil -> acc.reverse

fun parse-args(args : list<string>) : _ myflags
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
              f := f(verbosity=max(1, l.trim.parse-int.default(nothing=1)))
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

//========================================
// Verbose logging effect
//========================================

effect verbose-logging
  fun log-v(level : int, msg : string) : ()

fun log-info(msg)  log-v(1, "[ info  ] " ++ msg)
fun log-debug(msg) log-v(2, "[ debug ] " ++ msg)
fun log-error(msg) log-v(0, "[ error ] " ++ msg)

// level: 0 = errors only, 1 = info, 2 = debug, 3 = trace
fun verbose-logging(level : int, action : () -> <console,verbose-logging|e> ()) : <console|e> ()
  with fun log-v(lvl, msg)
    if lvl <= level then msg.println
  action()

//========================================
// Main handler
//========================================

val usage = r#"derive - auto derive functions for types and structs in koka.
Usage: derive [options] [FILE]

Options:
  -i, --input <file>       Input file, could also be argument
  -o, --output <file>      Output file (defaults to input file)
  -d, --derivable <kinds>  Comma-separated kinds: show, eq (repeatable)
  -V, --verbose[=N]        Verbose output (N: 1 info, 2 debug, 3 trace)
  -q, --quiet              Errors only
  -r, --dry-run            Print result without writing
  -v, --version            Show version
  -h, --help               Show this message

Arguments:
  FILE                     Input file, could also be -i
"#

fun handle-args(argv : list<string>)
  with verbose-logging(0)
  with catch fn(e : exception)
    log-error(e.show)

  val flag = parse-args(argv)

  with verbose-logging(flag.verbosity)


  if flag.version then
    println("derive: v1.0.0")
    return ()

  if flag.help then
    usage.println
    return ()

  if flag.input.is-empty then
    log-error("no input file specified")
    println("Usage: derive [options] [file]")
    return ()

  if flag.verbosity >= 1 then
    log-info("Received the flags:")
    log-info("  verbosity = " ++ flag.verbosity.int/show)
    log-info("  dry-run   = " ++ flag.dry-run.fork("true", "false"))
    log-info("  input     = " ++ (flag.input || r#""""#))
    log-info("  output    = " ++ (flag.output || r#""""#))
    log-info("  derivables= " ++ derivables-show(flag.derivables))

  log-info("Processing " ++ flag.input ++ "...")
  val result = process-file(flag.input, flag.derivables)

  log-debug("Result (" ++ flag.output ++ "):")
  result.lines.foreach-indexed fn(ix, l)
    log-debug(ix.show.pad-left(4) ++ " | " ++ l)

  if flag.dry-run.not then
    write-text-file(flag.output.path, result)

fun main()
  val args = get-args()
  args.handle-args
