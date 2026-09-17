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
      });
    };
}
