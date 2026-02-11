{ stdenv
, debTools
, pkgsStatic
, ...
}:

let
  staticDrv = pkgsStatic.callPackage ./package.nix { };
in

stdenv.mkDerivation {
  name = "hello-dual";

  src = ./.;

  buildPhase = ''
    runHook preBuild

    $CC hello.c -o hello

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 ./hello $out/bin/hello

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

  passthru.deb = debTools.debify
    (staticDrv.overrideAttrs {
      installPhase = ''
        runHook preInstall

        install -Dm755 ./hello $out/usr/bin/hello

        runHook postInstall
      '';
    })
    { };
}
