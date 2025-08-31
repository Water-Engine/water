{
  description = "Nix Flake for Water-Engine: A C++ chess engine powered by magic bitboard and neural networks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      nixpkgs,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      water-engine = pkgs.callPackage ./default.nix { };
    in
    {
      packages.${system}.default = water-engine;
      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ water-engine ];
      };
    };
}
