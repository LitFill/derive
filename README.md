# derive

A cli app for auto deriving functions that similar to GHC's deriving system.

## Supported functions

Currently supports:

- Show: by `pub fun type-name/show(t : type-name) // : string` (maybe \<div>)
- Eq: by `pub fun type-name/eq(t1, t2) // : bool` (maybe \<div>), and operator (==)

## Usage

```
derive - auto derive functions for types and structs in koka.
Usage: derive [options] FILE

Options:
 -i<file>             --input=file                                      Input file, could also be given as FILE
 -o<file>             --output=file                                     Output file (defaults to the input file)
 -d<kinds> -c<kinds>  --derivable=kinds --deriving=kinds --class=kinds  Comma-separated kinds: show, eq (repeatable)
 -V[N]                --verbose[=N]                                     Verbose output (N: 1 info, 2 debug, 3 trace)
 -q                   --quiet                                           Errors only
 -r                   --dry-run                                         Print result without writing
 -l                   --list                                            List supported derivables
 -v                   --version                                         Show version
 -h -?                --help                                            Show this message
```

A flag value may be given attached (`-ifile.kk`, `--input=file.kk`) or as the
next argument (`-i file.kk`, `--input file.kk`); both spellings work. Long
names may be abbreviated as long as it stays unambiguous, `--` ends the flags,
and `--no-<name>` turns off a boolean flag. See `derive --help`.
