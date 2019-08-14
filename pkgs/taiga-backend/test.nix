# Run `nix-build test.nix` to test the build of the taiga-back package.
let pkgs = import <nixpkgs> {}; in pkgs.callPackage ./default.nix {}
