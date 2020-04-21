# This module is used by the machine that runs my Matrix homeserver.
# REPLACES hologram-bethselamin-synapse
{ config, lib, pkgs, ... }:

with lib;

let

  fqdn = config.my.services.nginx.fqdn;
  cfg = config.services.matrix-synapse;

in {

  # To enable this module, the machine's configuration.nix must set:
  # - config.services.matrix-synapse.server_name
  # - config.services.matrix-synapse.macaroon_secret_key
  config = mkIf (cfg.macaroon_secret_key != null) {

    networking.firewall.allowedTCPPorts = [ 8448 ];

    services.nginx.virtualHosts.${cfg.server_name} = {
      forceSSL = true;
      enableACME = true;
      listen = [
        { addr = "[::]";    port = 80;   ssl = false; }
        { addr = "0.0.0.0"; port = 80;   ssl = false; }
        { addr = "[::]";    port = 443;  ssl = true; }
        { addr = "0.0.0.0"; port = 443;  ssl = true; }
        { addr = "[::]";    port = 8448; ssl = true; }
        { addr = "0.0.0.0"; port = 8448; ssl = true; }
      ];

      locations."/_matrix".proxyPass = "http://[::1]:8008";
    };

    services.matrix-synapse = {
      database_type = "sqlite3";
      enable = true;

      listeners = [
        {
          port = 8008;
          bind_address = "::1";
          resources = [ { compress = false;  names = [ "client" "federation" ]; } ];
          type = "http";
          tls = false;
          x_forwarded = true;
        }
      ];

      allow_guest_access = false;
      enable_registration = false;
    };
    # TODO: hardening

  };

}
