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
        inherit (drv.stdenv) hostPlatform;

        control = {
          Package = "${prev.name or prev.pname}";
          Version = "${prev.version or "0.0.0"}";
          Architecture = hostPlatform.go.GOARCH;
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

        libArchDirName = "${hostPlatform.parsed.cpu.name}-${hostPlatform.parsed.kernel.name}-${hostPlatform.parsed.abi.name}";
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
          binutils
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

          prefix="usr"
          libPath="/$prefix/lib/${libArchDirName}/${final.pname or final.name}"

          function isSymlink {
            [ -L "$1" ]
          }

          function isDynamicELF {
            readelf -l "$1" | grep -q "INTERP"
          }

          function installDynamicLibraries {
            local elf="$1"

            ldd "$elf" | awk '{print $1, $3}' | grep -v -e linux-vdso -e ld-linux | \
            while IFS=" " read -r lib path; do
              install -m555 "$path" "$out$libPath/$lib"
              installDynamicLibraries "$out$libPath/$lib"
            done || true

            local mode="$(stat -c '%a' "$elf")"
            chmod u+w "$elf"
            patchelf --set-rpath "$libPath" "$elf"
            chmod "$mode" "$elf"
          }

          function patchDynamicExecutable {
            local exe="$1"
            local interpreter="$(patchelf --print-interpreter "$exe")"
            local name="$(basename "$interpreter")"
            local mode="$(stat -c '%a' "$exe")"

            install -Dm555 "$interpreter" "$out$libPath/$name"

            chmod u+w "$exe"
            patchelf --set-interpreter "$libPath/$name" "$exe"
            chmod "$mode" "$exe"

            installDynamicLibraries "$exe"
          }

          function patchScript {
            local script="$1"
            local timestamp="$(stat -c '%y' "$script")"
            local mode="$(stat -c '%a' "$script")"
            local temp_script="$(mktemp -t patchScript.XXXXXXX)"

            chmod 600 "$temp_script"
            cat "$script" > "$temp_script"

            local line interpreter args name
            cat "$temp_script" | awk 'match($0, /#!\s*(\S+)\s*(.*)$/, a) {printf a[0] "\1" a[1] "\1" a[2] "\0"}' | \
            while IFS=$'\1' read -r -d $'\0' line interpreter args; do
              if [[ ! "$interpreter" == "$NIX_STORE"* ]]; then
                continue
              fi

              name="$(basename "$interpreter")"
              install -Dm555 "$interpreter" "$out$libPath/$name"
              patchDynamicExecutable "$out$libPath/$name"

              sed -i "s|^$line\$|#! $libPath/$name $args|gm" "$temp_script"
            done

            chmod u+w "$script"
            cat "$temp_script" > "$script"
            chmod "$mode" "$script"

            touch --date "$timestamp" "$script"
          }

          find $out -type f -print0 | \
          while IFS= read -r -d $'\0' file; do
            if isELF "$file"; then
              if isDynamicELF "$file"; then
                patchDynamicExecutable "$file"
                continue
              fi
            fi

            if isScript "$file"; then
              patchScript "$file"
              continue
            fi

            if isSymlink "$file"; then
              if realpath -m "$file" | grep -q "$NIX_STORE"; then
                echo "$file is a symlink pointing the nix store"
                exit 1
              fi

              continue
            fi
          done

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
