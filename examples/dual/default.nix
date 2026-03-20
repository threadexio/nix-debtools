{ pkgs ? import <nixpkgs> {
    overlays = [ (import ../../.) ];
  }
}:

rec {
  default = pkgs.callPackage ./package.nix { };
  deb = default.deb;
}
