{
  description = "CLI for deriving some useful functions for Koka types and structs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "derive";
        version = "v1.1.2";

        src = ./.;

        nativeBuildInputs = with pkgs; [
          koka
        ];

        buildPhase = ''
          koka -o build/derive app/main.kk
          chmod +x build/derive
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp build/derive $out/bin/
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          koka
        ];
      };
    };
}
