{ pkgs
, lib
, debTools
, ...
}:

final:

{ config ? ""
, preinst ? ""
, postinst ? ""
, prerm ? ""
, postrm ? ""

, nativeBuildInputs ? [ ]
, postPhases ? [ ]
, ...
}@args:

let
  inherit (pkgs.stdenv) hostPlatform;

  control = {
    Package = "${final.name or final.pname}";
    Version = "${final.version or "0.0.0"}";
    Architecture = hostPlatform.go.GOARCH;
  }
  // (lib.optionalAttrs (lib.hasAttr "meta" final) {
    Maintainer = map
      (x: "${x.name or x.github} <${x.email}>")
      (final.meta.maintainers or [ ]);

    Homepage = final.meta.homepage or null;
    Description = final.meta.description or null;
  })
  // (args.control or { });

  controlFormat = debTools.formats.control { };
  controlFile = controlFormat.generate "control" control;

  libArchDirName = "${hostPlatform.parsed.cpu.name}-${hostPlatform.parsed.kernel.name}-${hostPlatform.parsed.abi.name}";
in
{
  nativeBuildInputs = nativeBuildInputs ++ (with pkgs; [
    dpkg
    fakeroot
    patchelf
    binutils
  ]);

  postPhases = postPhases ++ [ "debPhase" ];

  fixupPhase = args.fixupPhase or ''
    local prefix="usr"
    local libPath="/$prefix/lib/${libArchDirName}/${final.pname or final.name}"
    ${builtins.readFile ./fixup.sh}
  '';

  debPhase = args.debPhase or ''
    local control="${controlFile}"
    ${builtins.readFile ./deb.sh}
  '';

  passthru = {
    inherit
      control
      config
      preinst
      postinst
      prerm
      postrm
      ;
  };
}
