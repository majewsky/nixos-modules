# This module is used by the machine that controls the vanity domain name of my Matrix homeserver.
# REPLACES hologram-bethselamin-synapse
{ config, lib, pkgs, ... }:

with lib;

let

  inherit (config.my.services.matrix-announce) serverDomainName vanityDomainName;

in {

  options.my.services.matrix-announce = {
    serverDomainName = mkOption {
      description = "domain name where the Matrix homeserver is deployed (default points to self)";
      default = config.my.services.nginx.fqdn;
      type = types.str;
    };
    vanityDomainName = mkOption {
      description = "domain name that users use to reach the Matrix homeserver";
      default = null;
      type = types.nullOr types.str;
    };
  };

  config = mkIf (vanityDomainName != null) {

    services.nginx.virtualHosts.${vanityDomainName} = {
      # this part courtesy of
      # https://nixos.org/nixos/manual/index.html#module-services-matrix
      locations."= /.well-known/matrix/server".extraConfig =
        let
          # use 443 instead of the default 8448 port to unite
          # the client-server and server-server port for simplicity
          server = { "m.server" = "${serverDomainName}:443"; };
        in ''
          add_header Content-Type application/json;
          return 200 '${builtins.toJSON server}';
        '';
      locations."= /.well-known/matrix/client".extraConfig =
        let
          client = {
            "m.homeserver"      = { "base_url" = "https://${serverDomainName}"; };
            "m.identity_server" = { "base_url" = "https://vector.im"; };
          };
        # ACAO required to allow riot-web on any URL to request this json file
        in ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '${builtins.toJSON client}';
        '';
    };

  };

}
