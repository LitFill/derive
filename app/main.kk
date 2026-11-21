module app/main

import std/os/env
import std/os/file
import std/os/path

import app/cli
import app/derive
import app/version

extern set-exit-code( code : int ) : () {
  c inline "(exit(kk_integer_clamp32(#1,kk_context())), kk_Unit)"
}

//========================================
// Main handler
//========================================


// What the flags ask us to do; the order here is the precedence.
type cli-action
  Show-version
  Show-help
  Show-list
  Usage-error(errs : list<string>)
  Process(flag : myflags)

fun classify-flags(flag : myflags) : cli-action
  if flag.version then
    Show-version
  elif flag.help then
    Show-help
  elif flag.list then
    Show-list
  elif flag.errors.is-nil.not then
    Usage-error(flag.errors)
  elif flag.input.is-empty then
    Usage-error([ "no input file specified" ])
  else
    Process(flag)

fun handle-args(argv : list<string>)
  with verbose-logging(0)
  with catch fn(e : exception)
    log-error(e.show)
    set-exit-code(1)

  val flag = parse-args(argv)

  with verbose-logging(flag.verbosity)

  match classify-flags(flag)
    Show-version ->
      version-string.println
    Show-help ->
      usage-text().println
    Show-list ->
      supported-derivables().println
    Usage-error(errs) ->
      errs.foreach(log-error(_))
      usage-text().println
      set-exit-code(1)
    Process(flag') ->
      if flag'.verbosity >= 1 then
        log-info("Received the flags: " ++ flag'.show)
      log-info("Processing " ++ flag.input ++ "...")
      val result = process-file(flag'.input, flag'.derivables)
      log-debug("Result (" ++ flag'.output ++ "):")
      result.lines.foreach-indexed fn(ix, l)
        log-debug(ix.show.pad-left(4) ++ " | " ++ l)
      if flag'.dry-run then
        result.print
      else
        write-text-file(flag'.output.path, result)

fun main()
  val args = get-args()
  args.handle-args
