{ pkgs ? import <nixpkgs> {
    overlays = [ (import ../../.) ];
  }
}:

pkgs.callPackage ./package.nix { }
