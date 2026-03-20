{ pkgs
, lib
, ...
}@inputs:

lib.extendMkDerivation {
  constructDrv = pkgs.stdenv.mkDerivation;

  excludeDrvArgNames = [
    "control"
    "config"
    "preinst"
    "postint"
    "prerm"
    "postrm"
  ];

  extendDrvArgs = import ./override.nix inputs;
}
