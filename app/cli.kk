module app/cli

import std/os/flags

import app/derive

//========================================
// Flags
//========================================

pub struct myflags
  verbosity  : int              = 0
  version    : bool             = False
  help       : bool             = False
  list       : bool             = False
  dry-run    : bool             = False
  input      : string           = ""
  output     : string           = ""
  derivables : list<derivable>  = []
  // Problems the setters below ran into. `parse` only reports the errors it
  // detects itself, and it is total, so a setter cannot throw -- it records
  // the problem here for the caller to report.
  errors     : list<string>     = []

pub fun myflags/show(m : myflags) : string
  "Myflags("
  ++ "verbosity="  ++ m.verbosity.int/show          ++ ", "
  ++ "version="    ++ m.version.bool/show           ++ ", "
  ++ "help="       ++ m.help.bool/show              ++ ", "
  ++ "dry-run="    ++ m.dry-run.bool/show           ++ ", "
  ++ "input="      ++ m.input.string/show           ++ ", "
  ++ "output="     ++ m.output.string/show          ++ ", "
  ++ "list="       ++ m.list.bool/show              ++ ", "
  ++ "derivables=" ++ derivables-show(m.derivables) ++ ", "
  ++ "errors="     ++ m.errors.list/show
  ++ ")"

// The setters must be total: `parse` demands `(a, string) -> a` and
// `(a, maybe<string>) -> a` with no further effect, so a flag that rejects its
// value records the reason in `myflags/errors` instead of raising.

fun set-version(f : myflags, b : bool) : myflags
  f(version=b)

fun set-help(f : myflags, b : bool) : myflags
  f(help=b)

fun set-list(f : myflags, b : bool) : myflags
  f(list=b)

fun set-dry-run(f : myflags, b : bool) : myflags
  f(dry-run=b)

fun set-quiet(f : myflags, b : bool) : myflags
  if b then f(verbosity=0) else f

fun set-verbosity(f : myflags, level : maybe<string>) : myflags
  match level
    Nothing -> f(verbosity=1)
    Just(n) ->
      // `-V2`, `-V=2` and `--verbose=2` all name a level, and a short flag
      // has no `=` of its own, so drop one that snuck in.
      val digits = if n.starts-with("=").is-just then n.list.drop(1).string else n
      f(verbosity=max(1, digits.trim.parse-int.default(1)))

fun set-input(f : myflags, s : string) : myflags
  f(input=s)

fun set-output(f : myflags, s : string) : myflags
  f(output=s)

fun set-derivable(f : myflags, arg : string) : myflags
  val (ds, errs) = parse-derivables(f.derivables, f.errors, arg.split(","))
  f(derivables=ds, errors=errs)

val flags-spec : list<flag<myflags>>
  = [ Flag( "i",  ["input"],  Req(set-input,  "file"),  "Input file, could also be given as FILE" ),
      Flag( "o",  ["output"], Req(set-output, "file"),  "Output file (defaults to the input file)" ),
      Flag( "dc", ["derivable", "deriving", "class"],
            Req(set-derivable, "kinds"), "Comma-separated kinds: show, eq (repeatable)" ),
      Flag( "V",  ["verbose"], Opt(set-verbosity, "N"), "Verbose output (N: 1 info, 2 debug, 3 trace)" ),
      Flag( "q",  ["quiet"],   Bool(set-quiet),         "Errors only" ),
      Flag( "r",  ["dry-run"], Bool(set-dry-run),       "Print result without writing" ),
      Flag( "l",  ["list"],    Bool(set-list),         "List supported derivables" ),
      Flag( "v",  ["version"], Bool(set-version),       "Show version" ),
      Flag( "h?", ["help"],    Bool(set-help),          "Show this message" ),
    ]

val usage-header : string
  = "derive - auto derive functions for types and structs in koka.\n"
  ++ "Usage: derive [options] FILE\n\nOptions:"

// Generated from `flags-spec`, so it cannot drift away from what is accepted.
pub fun usage-text() : string
  flags-spec.usage(usage-header)

//========================================
// Derivable names
//========================================

pub fun derivables-show(ds : list<derivable>) : string
  "[" ++ ds.map(_.derivable/show).join(", ") ++ "]"

pub fun supported-derivables() : string
  all-derivables.map(derivable/name).join(", ")

fun parse-derivable(s : string) : maybe<derivable>
  val name = s.trim.to-lower
  all-derivables.find(fn(d) d.derivable/name == name)

fun parse-derivables(acc : list<derivable>, errs : list<string>, parts : list<string>) : (list<derivable>, list<string>)
  match parts
    Cons(part, rest) ->
      val name = part.trim
      match name.parse-derivable
        Just(d) -> parse-derivables(Cons(d, acc), errs, rest)
        Nothing -> parse-derivables(acc, Cons("unknown derivable: " ++ name, errs), rest)
    Nil -> (acc.reverse, errs.reverse)

//========================================
// Argument parsing
//========================================

// `parse` reads a flag's value out of the single argv element that carries it
// (`--input=f`, `-if`) and has no way to look at the next element, so the
// separated spelling (`--input f`, `-i f`) has to be folded into the attached
// one first. These are the flags that can take a value.

val flags-with-required-value : list<string>
  = [ "-i", "-o", "-d", "-c", "--input", "--output", "--derivable", "--deriving", "--class" ]

val flags-with-optional-value : list<string>
  = [ "-V", "--verbose" ]

// A long flag separates its value with `=`, a short flag simply runs into it.
fun attach-value(flag : string, value : string) : string
  if flag.starts-with("--").is-just then flag ++ "=" ++ value else flag ++ value

fun takes-next-arg(flag : string, next : string) : bool
  if flags-with-optional-value.contains(flag) then
    // `-V` is valid on its own, so only swallow the next argument when it
    // really is a level: `derive -V -r f.kk` keeps -r a flag.
    next.parse-int.is-just
  elif flags-with-required-value.contains(flag) then
    // Likewise `-i -r` keeps -r a flag; a file name that starts with a dash
    // has to be written attached, as `-i-weird.kk` or `--input=-weird.kk`.
    next.starts-with("-").is-just.not
  else
    False

fun attach-separated-values(args : list<string>) : list<string>
  attach-args(args, False)

fun attach-args(args : list<string>, past-terminator : bool) : list<string>
  match args
    Nil -> Nil
    Cons(arg, rest) ->
      if past-terminator || arg == "--" then
        // Past `--` nothing is a flag, so pass the rest through untouched.
        Cons(arg, attach-args(rest, True))
      else
        match rest
          Cons(next, rest2) ->
            if takes-next-arg(arg, next) then
              Cons(attach-value(arg, next), attach-args(rest2, False))
            else
              Cons(arg, attach-args(rest, False))
          Nil -> Cons(arg, Nil)

pub fun parse-args(args : list<string>) : myflags
  val (parsed, positional, errs) = parse(Myflags(), flags-spec, attach-separated-values(args))
  // `parse` conses the non-flag arguments on in reverse, and the file
  // argument is the first one, so put them back in command-line order.
  val f = parsed(errors=errs.reverse ++ parsed.errors)
  // A bare FILE stands in for -i, and the output defaults to whatever the
  // input ended up being, however it was named.
  val g = match positional.reverse
           Cons(file, _) -> if f.input.is-empty then f(input=file) else f
           Nil           -> f
  if g.output.is-empty then g(output=g.input) else g

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
