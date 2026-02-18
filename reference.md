# Reference

The flake provides an overlay which can be integrated in your own instance of
`nixpkgs`.

```nix
import nixpkgs {
  overlays = [
    (import nix-debtools)
  ];
}
```

The overlay adds `pkgs.debTools`. A collection of utilities to help you produce
`.deb` packages. See below for detailed documentation.

## `pkgs.debTools.debify`

```nix
pkgs.debTools.debify -> drv -> args
```

Mainly you are going to be using this function to "convert" normal Nix
derivations to ones which produce `.deb` packages.

> [!NOTE]
> This function **cannot** map a derivation designed for Nix to a Debian package
> 1-1. There are fundamental differences between the 2 distros. You most
> definitely will have to do some work by hand.

This function simply overrides the given derivation and adds the bits and bobs
to make it build a `.deb` archive. The `args` argument is an attribute set
which allows tweaking the resulting package. It follows the format:

```nix
{
  # Additional fields for the DEBIAN/control file.
  # See: https://www.debian.org/doc/debian-policy/ch-controlfields.html
  control = {
    Depends = [ "libc (>= 2.11)" ];
    Homepage = "https://example.com";
  };

  # `config` script
  config = ''
    echo "Hello!"
  '';

  # `preinst` script
  preinst = ''
    echo "Hello!"
  '';

  # `postinst` script
  postinst = ''
    echo "Hello!"
  '';
  
  # same for `prerm` and `postrm`
}
```

All of the fields in `args` are _optional_. Most things for `control` are taken
from the original derivation's `meta` attribute (but can still be overriden
from `args`). If you package needs dependencies from Debian's repos, you need
to specify them manually via `control.Depends`, `control.Conflicts`, etc.
Dependencies are not tracked automatically.

The creation of the `.deb` archive happens in a special post phase called
`debPhase`. The normal hook convention of `preDeb` and `postDeb` apply, so if
you need to do things before or after use them.

### Examples

```nix
{ hello
, debTools
, ...
}:

debTools.debify hello {}
```

> [!NOTE]
> All dependencies of the derivation will be brought along in the `.deb`
> package. This means any libraries, interpreters, etc will be contained in
> `.deb` package. Since we cannot ensure that the versions of the libraries we
> build against in Nix will be available in Debian, we have to bring them along.
> For example, if a shell script wants the `/nix/store/XXXX-bash-X.X.X/bin/bash`
> interpreter, then that specific version of bash (and any dependencies of
> it) will be bundled inside the `.deb` package. The same also applies for
> dynamically linked executables. If possible, prefer building static binaries
> and using pre-installed script interpreters.

Also see: [`examples/`](./examples).

## `pkgs.debTools.formats.control`

The format of the [Debian control file]. Same API as `pkgs.formats.*`. You
shouldn't really ever need this since `debify` already provides this but it's
there in the case you do.

[Debian control file]: https://www.debian.org/doc/debian-policy/ch-controlfields.html

`generate` returns a `writeText` derivation which contains the text of the
`DEBIAN/control` file.

### Example

```nix
let
  controlFormat = pkgs.debTools.formats.control {};
in

controlFormat.generate {
  Package = "hello";
  Version = "1.0";
  Depends = [ "libc" ];
  Description = ''
    A simple hello world program.
  '';
  Maintainer = "John Doe <jdoe@example.com>";
}
```
