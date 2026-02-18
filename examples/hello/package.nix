{ stdenv
, openssl
, debTools
, ...
}:

let
  drv = stdenv.mkDerivation {
    name = "hello";

    src = ./.;

    nativeBuildInputs = [
      openssl
    ];

    buildPhase = ''
      runHook preBuild

      $CC hello.c -o hello -lssl -lcrypto

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 ./hello $out/usr/bin/hello

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
