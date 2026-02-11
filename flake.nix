{
  description = "Nixpkgs addon for producing Debian packages.";

  inputs = { };

  outputs = { ... }: {
    overlays.default = import ./.;
  };
}
