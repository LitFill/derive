# derive

A cli app for auto deriving functions that similar to GHC's deriving system.

## Supported functions

Currently supports:

- Show: by `pub fun type-name/show(t : type-name) // : string` (maybe \<div>)
- Eq: by `pub fun type-name/eq(t1, t2) // : bool` (maybe \<div>), and operator (==)

## Usage

```
derive - auto derive functions for types and structs in koka.
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
```
