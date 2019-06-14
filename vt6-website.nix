# This module renders vt6.io from https://github.com/vt6/vt6

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.vt6-io;

  texlive = pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-small collection-latex collection-mathscience collection-pictures standalone;
  };

  vt6-website-build = pkgs.callPackage ./pkgs/vt6-website-build/default.nix {};

  build-vt6-website-sh = pkgs.writeScript "build-vt6-website.sh" ''
    #!/bin/sh
    set -euo pipefail
    CHECKOUT_DIR="$1"
    TARGET_DIR="$2"
    export PATH="/run/current-system/sw/bin:$PATH"
    vt6-website-build "$CHECKOUT_DIR" "$TARGET_DIR"
  '';

in {

  options.my.services.vt6-io = {
    # The `domainName` option is the only required configuration option (we
    # need a domain name for getting a TLS cert with ACME), so it takes the
    # role of `enable`.
    domainName = mkOption {
      default = null;
      description = "domain name for VT6 website (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    environment.systemPackages = [ pkgs.pdf2svg texlive vt6-website-build ];

    my.services.staticweb.sites.${cfg.domainName} = {
      repositoryName = "vt6/vt6";
      buildCommand = toString build-vt6-website-sh;
    };

  };

}
