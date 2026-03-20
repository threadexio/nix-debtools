if [ -n "${dontDeb:-}" ]; then return; fi

function installScript {
  local name="$1"

  local text
  typeset -n text="$name"

  if [ -n "$text" ]; then
    printf "%s\n\n" "#! /usr/bin/bash" > "$out/DEBIAN/$name"
    printf "%s" "$text" >> "$out/DEBIAN/$name"
    chmod 755 "$out/DEBIAN/$name"
  fi
}

runHook preDeb

mkdir -p --mode=0755 "$out/DEBIAN"
install -m644 "$control" "$out/DEBIAN/control"
installScript "config"
installScript "preinst"
installScript "postinst"
installScript "prerm"
installScript "postrm"

if [ ! -n "$dontDebArchive" ]; then
  local build_dir="$(mktemp -d -u -t debtools.XXXXXX)"

  mv "$out" "$build_dir"
  fakeroot -- dpkg-deb --build "$build_dir" "$out"
else
  echo "skipping deb archive generation"
fi

runHook postDeb
