{ pkgs ? import <nixpkgs> {
    overlays = [ (import ../../.) ];
  }
}:

pkgs.pkgsStatic.callPackage ./package.nix { }
