{ lib
, pkgs
, ...
}:

{}:
{
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
}
