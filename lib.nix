{ pkgs
, lib
, ...
}:

lib.makeExtensible (debTools: {
  formats = {
    control = {}: {
      type = with lib.types;
        attrsOf (
          nullOr (
            oneOf [
              str
              (listOf str)
              int
              float
              bool
            ]
          )
        );

      generate = name: value:
        let
          toControlField = name: value:
            if value == null then
              null
            else if lib.isList value then
              if lib.length value == 0 then
                null
              else
                "${name}: " + (lib.concatStringsSep ",\n " value)
            else
              "${name}: " + (lib.concatStringsSep "\n "
                (map (line: if line == "" then "." else line)
                  (map (lib.trimWith { end = true; })
                    (lib.splitString "\n"
                      (lib.trimWith { end = true; }
                        (toString value)
                      )
                    )
                  )
                )
              )
          ;

          lines =
            lib.filter (x: x != "")
              (map lib.trim
                (lib.filter (x: x != null)
                  (lib.mapAttrsToList toControlField value)
                )
              );

          text = (lib.concatStringsSep "\n" lines) + "\n";
        in
        pkgs.writeText name text;
    };
  };

  debify = drv: args:
    drv.overrideAttrs (final: prev:
      let
        control = {
          Package = "${prev.name or prev.pname}";
          Version = "${prev.version or "0.0.0"}";
          Architecture = drv.stdenv.hostPlatform.go.GOARCH;
        }
        // (lib.optionalAttrs (lib.hasAttr "meta" prev) {
          Maintainer = map
            (x: "${x.name or x.github} <${x.email}>")
            (prev.meta.maintainers or [ ]);

          Homepage = prev.meta.homepage or null;
          Description = prev.meta.description or null;
        })
        // (args.control or { });

        controlFormat = debTools.formats.control { };
        controlFile = controlFormat.generate "control" control;
      in
      {
        passthru = args // {
          inherit control;

          config = args.config or "";
          preinst = args.preinst or "";
          postinst = args.postinst or "";
          prerm = args.prerm or "";
          postrm = args.postrm or "";
        };

        nativeBuildInputs = with pkgs; [
          dpkg
          fakeroot
          patchelf
        ]
        ++ (prev.nativeBuildInputs or [ ]);

        postPhases = (prev.postPhases or [ ]) ++ [ "debPhase" ];

        postInstall =
          let
            installScript = name:
              lib.optionalString (final.passthru.${name} != "") (
                let
                  path = pkgs.writeText name
                    ("#! /usr/bin/bash\n" + final.passthru.${name});
                in
                "install -m755 ${path} $out/DEBIAN/${name}\n"
              );
          in
          (prev.postInstall or "")
          + ''
            mkdir --mode=0755 $out/DEBIAN
            install -m644 ${controlFile} $out/DEBIAN/control
          ''
          + (installScript "config")
          + (installScript "preinst") + (installScript "postinst")
          + (installScript "prerm") + (installScript "postrm");

        fixupPhase = ''
          if [ ! -d $out/DEBIAN ]; then
            echo "the debian package metadata was not found. (maybe you forgot to run the postInstall hook?)"
            exit 1
          fi

          runHook preFixup

          if find $out/. -type l -exec realpath -m {} \; | grep -q /nix/store; then
            echo "found a symlink pointing inside /nix/store"
            exit 1
          fi

          if find $out/. -type f -executable -exec patchelf --print-interpreter {} \; 2>/dev/null | grep -q /nix/store; then
            echo "found an executable whose interpreter references /nix/store"
            exit 1
          fi

          if find $out/. -type f -executable -exec grep -E "^#!" {} \; 2>/dev/null | grep -q /nix/store; then
            echo "found a script whose shebang references /nix/store"
            exit 1
          fi

          runHook postFixup
        '';

        debPhase = ''
          runHook preDeb

          mv $out deb
          fakeroot -- dpkg-deb --build deb $out

          runHook postDeb
        '';
      });
})
