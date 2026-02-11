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

The creation of the `.deb` archive happens in a special custom phase called
`debPhase`. The normal hook convention of `preDeb` and `postDeb` apply, so if
you need to do things before or after use them.

### Examples

```nix
{ pkgsStatic
, debTools
, ...
}:

debTools.debify pkgsStatic.hello {}
```

Also see: [`examples/`](./examples).

> [!NOTE]
> We need to provide `hello` from `pkgsStatic` because otherwise the built
> binary will have references to `/nix/store` which is not available on Debian
> systems and is thus disallowed. Most architecture-dependent packages will have
> to be built this way. The alternative is to figure out what versions of your
> dependencies exist in the Debian repos, pin the same version in the derivation
> and setup the toolchain to link to standard FHS paths. At that point you might
> as well forego this entire hack of a flake and add proper support for Debian
> packages.

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
