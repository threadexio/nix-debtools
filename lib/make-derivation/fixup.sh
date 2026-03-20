if [ -n "${dontFixup:-}" ]; then return; fi

function isSymlink {
  [ -L "$1" ]
}

function isDynamicELF {
  readelf -l "$1" | grep -q "INTERP"
}

function installDynamicLibraries {
  local elf="$1"

  local lib path

  (ldd "$elf" | awk '{print $1, $3}' | grep -v -e linux-vdso -e ld-linux | \
    while IFS=" " read -r lib path; do
      install -m555 "$path" "$out$libPath/$lib"
      installDynamicLibraries "$out$libPath/$lib"
    done) || true

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

runHook preFixup

test -d "$out/bin" && mkdir -p "$out/$prefix" && mv "$out/bin" "$out/$prefix/bin"
test -d "$out/lib" && mkdir -p "$out/$prefix" && mv "$out/lib" "$out/$prefix/lib"
test -d "$out/share" && mkdir -p "$out/$prefix" && mv "$out/share" "$out/$prefix/share"
test -d "$out/nix-support" && rm -rf "$out/nix-support"

find "$out" -type f -print0 | \
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
