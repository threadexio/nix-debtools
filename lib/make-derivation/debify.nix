{ ...
}@inputs:

let
  override = import ./override.nix inputs;
in

drv: drv.overrideAttrs override
