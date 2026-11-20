{
  description = "CLI for deriving some useful functions for Koka types and structs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        derive = pkgs.stdenv.mkDerivation {
          pname = "derive";
          version = "1.1.2";
          src = self;

          nativeBuildInputs = with pkgs; [
            koka
            stdenv.cc # koka shells out to a C compiler for codegen
          ];

          strictDeps = true;

          buildPhase = ''
            runHook preBuild
            koka -o derive app/main.kk
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 derive $out/bin/derive
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "CLI for deriving some useful functions for Koka types and structs";
            mainProgram = "derive";
            platforms = platforms.unix;
          };
        };

        default = derive;
      });

      apps = nixpkgs.lib.genAttrs systems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.derive}/bin/derive";
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            koka
          ];
        };
      });

      # End-to-end regression check: deriving sample.kk must reproduce
      # the checked-in sample-derived.kk byte for byte.
      checks = nixpkgs.lib.genAttrs systems (system: {
        derive-sample =
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          pkgs.runCommand "derive-sample"
            {
              nativeBuildInputs = [ pkgs.diffutils ];
            }
            ''
              ${self.packages.${system}.derive}/bin/derive -i ${./sample.kk} -o derived.kk
              diff ${./sample-derived.kk} derived.kk
              touch $out
            '';
        derive-cli =
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          pkgs.runCommand "derive-cli"
            {
              nativeBuildInputs = [ pkgs.diffutils ];
            }
            ''
              set -euo pipefail

              derive=${self.packages.${system}.derive}/bin/derive
              sample=${./sample.kk}
              expected=${./sample-derived.kk}

              work=$(mktemp -d)
              trap 'rm -rf "$work"' EXIT
              cd "$work"

              fail() { echo "FAIL: $*" >&2; exit 1; }
              has() { grep -qF -- "$1" "$2" || fail "$2 missing: $1"; }
              hasnt() { ! grep -qF -- "$1" "$2" || fail "$2 unexpected: $1"; }

              expect-exit() {
                want=$1
                shift
                set +e
                "$@" > last.log 2>&1
                got=$?
                set -e
                [ "$got" -eq "$want" ] || fail "exit $got != $want: $*"
              }

              # --version and --list
              [ "$($derive --version)" = "derive: v1.1.2" ] || fail "--version"
              [ "$($derive --list)" = "show, eq" ] || fail "--list"
              $derive --version > /dev/null
              $derive --list > /dev/null

              # --help documents the list flag
              $derive --help > help.txt
              has "Usage: derive [options] FILE" help.txt
              has "--list" help.txt

              # -r prints to stdout and writes nothing
              $derive -r -i "$sample" -o dry.kk > dry.out
              diff "$expected" dry.out || fail "dry-run output"
              [ ! -e dry.kk ] || fail "dry-run wrote dry.kk"

              # normal run writes the file, stdout stays empty
              $derive -i "$sample" -o out.kk > out.stdout
              [ ! -s out.stdout ] || fail "normal run printed to stdout"
              diff "$expected" out.kk || fail "normal output"

              # attached and separated spellings agree
              $derive -i"$sample" -oattached.kk
              $derive --input="$sample" --output=long.kk
              $derive -i "$sample" -o separated.kk
              for f in attached.kk long.kk separated.kk; do
                diff "$expected" "$f" || fail "$f"
              done

              # -d show keeps show only and rewrites the directive
              $derive -d show -i "$sample" -o show.kk
              hasnt "/eq" show.kk
              has "/show" show.kk
              has "// boolean.derive(eq)" show.kk

              # default parameter values, function types, and multi-line parens
              cat > defaults.kk <<'EOF'
struct config(
  verbose : bool = False,
  name : string = ""
)

// config.derive(show, eq)

type state<a>
  Empty
  Values(value : a, values : list<a> = [])
  Waiting(listener : a -> ioc (), listeners : list<a -> ioc ()> = [])

// state.derive(show, eq)

abstract value struct point(x : int = 0, y : int = 0)

// point.derive(show, eq)
EOF
              $derive -i defaults.kk -o defaults-out.kk
              has "co__derived_show.verbose" defaults-out.kk
              has "co__derived_show.name" defaults-out.kk
              has "co__derived_eq_1.verbose == co__derived_eq_2.verbose" defaults-out.kk
              has "Values(value=" defaults-out.kk
              has "Waiting(listener=" defaults-out.kk
              has "po__derived_show.x" defaults-out.kk
              has "po__derived_show.y" defaults-out.kk

              # repeated and comma-separated kinds both select show+eq
              $derive -d show -d eq -i "$sample" -o repeated.kk
              diff "$expected" repeated.kk || fail "repeated -d"
              $derive --derivable=show,eq -i "$sample" -o comma.kk
              diff "$expected" comma.kk || fail "comma -d"

              # verbosity: -V info, -V2 / -V 2 / -V=2 debug, -q silences
              $derive -V -i "$sample" -o v1.kk > v1.log
              has "[ info  ]" v1.log
              hasnt "[ debug ]" v1.log

              $derive -V2 -i "$sample" -o v2.kk > v2.log
              has "[ debug ]" v2.log
              $derive -V 2 -i "$sample" -o v2sep.kk > v2sep.log
              has "[ debug ]" v2sep.log
              $derive -V=2 -i "$sample" -o v2eq.kk > v2eq.log
              has "[ debug ]" v2eq.log

              $derive -V2 -q -i "$sample" -o quiet.kk > quiet.log
              [ ! -s quiet.log ] || fail "quiet was not quiet"

              # `--` ends flags, and --no-dry-run is accepted
              $derive -o dashdash.kk -- "$sample"
              diff "$expected" dashdash.kk || fail "-- output"
              $derive --no-dry-run -i "$sample" -o nodry.kk > nodry.log
              [ ! -s nodry.log ] || fail "--no-dry-run printed"
              diff "$expected" nodry.kk || fail "--no-dry-run output"

              # output defaults to the input file
              cp "$sample" in.kk
              chmod u+w in.kk
              $derive -i in.kk
              diff "$expected" in.kk || fail "default output"

              # errors are reported and exit nonzero
              expect-exit 1 "$derive" -d bogus -i "$sample"
              has "unknown derivable: bogus" last.log
              has "Usage: derive" last.log

              expect-exit 1 "$derive"
              has "no input file specified" last.log

              expect-exit 1 "$derive" -i "$work/no-such-file.kk"
              has "unable to read text file" last.log

              touch blocker
              expect-exit 1 "$derive" -i "$sample" -o "$work/blocker/out.kk"
              has "unable to write text file" last.log

              touch $out
            '';
      });
    };
}
