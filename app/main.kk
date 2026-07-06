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
  verbose   : bool      = False
  version   : bool      = False
  help      : bool      = False
  dry-run   : bool      = False
  input     : string    = ""
  output    : string    = ""
  derivable : derivable = Show

fun myflags/show(m : myflags)
  "Myflags("
  ++ "verbose="   ++ m.verbose.bool/show  ++ ", "
  ++ "version="   ++ m.version.bool/show  ++ ", "
  ++ "help="      ++ m.help.bool/show     ++ ", "
  ++ "dry-run="   ++ m.dry-run.bool/show  ++ ", "
  ++ "input="     ++ m.input.string/show  ++ ", "
  ++ "output="    ++ m.output.string/show ++ ", "
  ++ "derivable=" ++ m.derivable.derivable/show
  ++ ")"

// HACK: Manual flag parsing
// TODO: Use a more robust flag parsing library (or write it)
// but I'm quite proud of it
//       Currently supports: --verbose/-V, --help/-h, --version/-v,
//       --dry-run/-r, -o/--output, -i/--input, --derivable/-d/--class/-c
fun parse-args(args : list<string>) : _ myflags
  var f := Myflags()
  fun loop(xs : list<string>) : _ ()
    match xs
      Cons(flag, rest)
        | flag.elem(["--verbose", "-V"]) ->
          f := f(verbose=True)
          loop(rest)
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
          val d =
            if arg.elem(["show", "Show"]) then Show
            elif arg.elem(["eq", "Eq"]) then Eq
            else Show
          f := f(derivable=d)
          loop(rest)
      Cons(arg) ->
        f := f(input=arg)
        if f.output.is-empty then
          f := f(output=arg)
      Nil -> ()
  loop(args)
  f

//========================================
// Verbose logging effect
//========================================

effect verbose-logging
  // TODO: handle different verbosity/logging level
  //       Currently verbose is a boolean flag; extend to support levels:
  //       --quiet, --verbose=1/2/3 for info/debug/trace
  fun log-v(msg : string) : ()

fun log-info(msg)  log-v("[ info  ] " ++ msg)
fun log-debug(msg) log-v("[ debug ] " ++ msg)
fun log-error(msg) log-v("[ error ] " ++ msg)

fun verbose-logging(cond : bool, action : () -> <console,verbose-logging|e> ()) : <console|e> ()
  with fun log-v(msg) if cond then msg.println
  action()

//========================================
// Main handler
//========================================
fun handle-args(argv : list<string>)
  val flag = parse-args(argv)
  with verbose-logging(flag.verbose)
  with catch fn(e : exception)
    log-error(e.show)
  if flag.version then
    println("derive: v1.0.0")
    return ()
  if flag.help then
    println("derive - auto derive functions for types and structs in koka.")
    println("Usage: derive [options] [FILE]")
    println("")
    println("Options:")
    println("  -i, --input <file>       Input file, could also be argument")
    println("  -o, --output <file>      Output file (defaults to input file)")
    println("  -d, --derivable <kind>   Derivable kind: show (default) or eq")
    println("  -V, --verbose            Verbose output")
    println("  -r, --dry-run            Print result without writing")
    println("  -v, --version            Show version")
    println("  -h, --help               Show this message")
    println("")
    println("Arguments:")
    println("  FILE                     Input file, could also be -i")
    return ()
  if flag.input.is-empty then
    log-error("no input file specified")
    println("Usage: derive [options] [file]")
    return ()

  log-info("Received the flags:")
  val cond = dry-run(flag)
  // log-info("  dry-run   = " ++ (if flag.dry-run then "true" else "false"))
  log-info("  dry-run   = " ++ flag.dry-run.fork("true", "false"))
  log-info("  input     = " ++ (flag.input || r#""""#))
  log-info("  output    = " ++ (flag.output || r#""""#))
  log-info("  derivable = " ++ flag.derivable.derivable/show)

  log-info("Processing " ++ flag.input ++ "...")
  val result = process-file(flag.input)
  log-debug("Result (" ++ flag.output ++ "):")
  result.lines.foreach-indexed fn(ix, l)
    log-debug(ix.show.pad-left(4) ++ " | " ++ l)
  if flag.dry-run.not then
    write-text-file(flag.output.path, result)

fun main()
  val args = get-args()
  args.handle-args
