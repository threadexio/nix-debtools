{ ...
}@inputs':

let
  inputs = inputs' // { inherit debTools; };

  formats = {
    control = import ./formats/control.nix inputs;
  };

  mkDerivation = import ./make-derivation inputs;

  debify = import ./make-derivation/debify.nix inputs;

  attachDeb = attachDebWithName "deb";

  attachDebWithName = name: drv:
    drv.overrideAttrs (_: _: {
      passthru."${name}" = debify drv;
    });

  debTools = {
    inherit
      formats
      mkDerivation
      debify
      attachDeb
      attachDebWithName
      ;
  };
in

debTools
