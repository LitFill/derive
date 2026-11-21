# derive

A cli app for auto deriving functions that similar to GHC's deriving system.

## Supported functions

Currently supports:

- Show: by `pub fun type-name/show(t : type-name) // : string` (maybe \<div>)
- Eq: by `pub fun type-name/eq(t1, t2) // : bool` (maybe \<div>), and operator (==)
- Cmp: by `pub fun type-name/cmp(t1, t2) : order`, and operator (`<=>`). Constructors are ordered by declaration; struct fields are compared left to right with short-circuit on non-`Eq`.

## Usage

```
derive - auto derive functions for types and structs in koka.
Usage: derive [options] FILE

Options:
 -i<file>             --input=file                                      Input file, could also be given as FILE
 -o<file>             --output=file                                     Output file (defaults to the input file)
 -d<kinds> -c<kinds>  --derivable=kinds --deriving=kinds --class=kinds  Comma-separated kinds: show, eq, cmp (repeatable)
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

## Development

This project is managed by [koki](https://github.com/LitFill/koki): `flake.nix`
carries the `# koki:inputs` and `# koki:libs` marker regions that `koki add`
writes to, so dependencies stay in step with the compiler flags and with the
`koka.json` that editors read.

| command | what it does |
|---|---|
| `koki dev` | enter a shell with koka; writes `koka.json` |
| `koki build` | `nix build` — binary lands in `./result` |
| `koki run -- -i sample.kk` | build and run; `--` keeps the rest for derive |
| `koki check` | `nix flake check` — sample diff plus the CLI regression matrix |
| `koki add nel-kk` | add a Koka library as a flake input |
| `koki info` / `koki doctor` | what koki knows about the project / toolchain check |

A release bumps the version in both `flake.nix` and `app/main.kk`
(`derive-cli` asserts the two agree) and tags the commit, e.g. `v1.2.0`.
