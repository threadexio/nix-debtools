final: prev: {
  debTools = (prev.debTools or { }) // (import ./lib {
    pkgs = final;
    inherit (final) lib;
  });
}
