{ stdenv
, debTools
, ...
}:

# Note how we use `pkgs.pkgsStatic.callPackage` instead of just `pkgs` in
# `default.nix`.

let
  drv = stdenv.mkDerivation {
    name = "hello";

    src = ./.;

    buildPhase = ''
      runHook preBuild

      $CC hello.c -o hello

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -m755 ./hello $out/usr/bin/hello

      runHook postInstall
    '';

    meta = {
      description = ''
        A simple hello world program.

        It prints a greeting.
      '';

      maintainers = [
        {
          github = "John Doe";
          email = "jdoe@example.com";
        }
      ];
    };
  };
in

debTools.debify drv { }
