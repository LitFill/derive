module app/main

import std/os/env
import std/os/file
import std/os/path

import app/cli
import app/derive

//========================================
// Utilities
//========================================

inline fun bool/fork(cond, a, b) if cond then a else b

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
    println("derive: v1.1.2")
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
