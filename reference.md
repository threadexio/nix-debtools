# Reference

The flake provides an overlay which can be integrated in your own instance of `nixpkgs`.

```nix
import nixpkgs {
  overlays = [
    (import nix-debtools)
  ];
}
```

The overlay adds `pkgs.debTools`. A collection of utilities to help you produce `.deb`
packages. See below for detailed documentation.

---

## `pkgs.debTools.mkDerivation`

This function creates a derivation, like `stdenv.mkDerivation`, only the resulting
derivation builds a Debian package.

`mkDerivation` is _not_ magic. It is not able to take any arbitrary Nix package and
turn it into a Debian package. The resulting Debian package will be self-contained.
All library dependencies, executables, shell scripts, etc will be patched to work
with the FHS-compliant filesystem of Debian. For this reason, the packages built
with `debTools.mkDerivation` will larger in size than "native" Debian packages, since
`debTools.mkDerivation` brings along binaries, libraries and interpreters so the built
application works the same as in Nix. If you would like to opt out of this behavior, it
will be necessary to patch the build manually so as not to contain references to the Nix
store.

The attribute set expected by this function is the same as the one for
`stdenv.mkDerivation`. However, it accepts some extra options:

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

Most things for `control` are taken from the original derivation's `meta` attribute (but
can still be overriden). If you package needs dependencies from Debian's repos, you need
to specify them manually via `control.Depends`, `control.Conflicts`, etc. Dependencies are
not tracked automatically.

The creation of the `.deb` archive happens in a special post phase called `debPhase`. The
normal hook convention of `preDeb` and `postDeb` apply, so if you need to do things before
or after use them.

> [!NOTE]
> All dependencies of the derivation will be brought along in the `.deb` package. This
> means any libraries, interpreters, etc will be contained in `.deb` package. Since
> we cannot ensure that the versions of the libraries we build against in Nix will be
> available in Debian, we have to bring them along. For example, if a shell script wants
> the `/nix/store/XXXX-bash-X.X.X/bin/bash` interpreter, then that specific version of
> bash (and any dependencies of it) will be bundled inside the `.deb` package. The same
> also applies for dynamically linked executables. If possible, prefer building static
> binaries and using pre-installed script interpreters.

### Examples

<details><summary>

#### `pkgs.debTools.mkDerivation` example of a hello package in C

</summary>

```nix
pkgs.debTools.mkDerivation {
  pname = "hello";
  version = "0.1.0";

  src = ./.;

  buildPhase = ''
    cc hello.c -o hello
  '';

  installPhase = ''
    install -Dm755 ./hello $out/bin/hello
  '';
}
```

</details>

<details><summary>

#### `pkgs.debTools.mkDerivation` example with maintainer scripts

</summary>

```nix
pkgs.debTools.mkDerivation {
  name = "hello";

  buildPhase = ''
    # ...
  '';

  installPhase = ''
    # ...
  '';

  prerm = ''
    echo "being removed!"
  '';

  postinst = ''
    echo "installed!"
  '';
}
```

</details>

Also see: [`examples/`](./examples).

---

## `pkgs.debTools.debify`

"debify" an already made derivation.

This function takes an already-made derivation and transforms it such that it builds a
Debian package instead. It is equivalent to using [`pkgs.debTools.mkDerivation`].

### Inputs

#### `drv`

The input derivation.

### Type

```nix
pkgs.debTools.debify :: Derivation -> Derivation
```

### Examples

<details><summary>

#### `pkgs.debTools.debify` usage

</summary>

```nix
pkgs.debTools.debify pkgs.hello
```

</details>

<details><summary>

#### `pkgs.debTools.debify` usage with maintainer scripts

</summary>

```nix
pkgs.debTools.debify (pkgs.hello.overrideAttrs (_: _: {
  preinst = ''
    echo "installing hello..."
  '';

  postinst = ''
    echo "installed hello :)"
  '';

  prerm = ''
    echo "removing hello..."
  '';

  postrm = ''
    echo "removed hello :("
  '';
})
```

</details>

Also see: [`examples/`](./examples).

---

## `pkgs.debTools.attachDeb`

Attach a `deb` passthru attribute to a derivation.

This function takes an input derivation and returns the same derivation with
`passthru.deb` set to the [deb-ification](#pkgsdebtoolsmkderivation) of the
derivation.

### Inputs

#### `drv`

The input derivation.

### Type

```nix
pkgs.debTools.attachDeb :: Derivation -> Derivation
```

### Examples

<details><summary>

#### `pkgs.debTools.attachDeb` usage

</summary>

```nix
pkgs.debTools.attachDeb pkgs.hello
```

</details>

---

## `pkgs.debTools.attachDebWithName`

Same as [`pkgs.debTools.attachDeb`] but instead of setting `passthru.deb`, it
sets `passthru.${name}`.

### Inputs

#### `name`

Name of the attribute in the input derivation's `passthru`.

#### `drv`

The input derivation.

### Type

```nix
pkgs.debTools.attachDebWithName :: String -> Derivation -> Derivation
```

---

## `pkgs.debTools.formats.control`

The format of the [Debian control file]. Same API as `pkgs.formats.*`. You shouldn't
really ever need this since `mkDerivation` and `debify` already provide this but it's
there in the case you do.

[Debian control file]: https://www.debian.org/doc/debian-policy/ch-controlfields.html

`generate` returns a `writeText` derivation which contains the text of the
`DEBIAN/control` file.

### Examples

<details><summary>

#### `pkgs.debTools.formats.control` usage example

</summary>

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

</details>

[`pkgs.debTools.mkDerivation`]: #pkgsdebtoolsmkderivation
[`pkgs.debTools.debify`]: #pkgsdebtoolsdebify
[`pkgs.debTools.attachDeb`]: #pkgsdebtoolsattachdeb
[`pkgs.debTools.attachDebWithName`]: #pkgsdebtoolsattachdebwithname
[`pkgs.debTools.formats.control`]: #pkgsdebtoolsformatscontrol
