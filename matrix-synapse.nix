# This module is used by the machine that runs my Matrix homeserver.
# REPLACES hologram-bethselamin-synapse
{ config, lib, pkgs, ... }:

with lib;

let

  fqdn = config.my.services.nginx.fqdn;
  cfg = config.services.matrix-synapse;

in {

  # To enable this module, the machine's configuration.nix must set:
  # - config.services.matrix-synapse.server_name (the vanity domain name)
  # - config.services.matrix-synapse.macaroon_secret_key
  config = mkIf (cfg.macaroon_secret_key != null) {

    my.services.nginx.fqdnLocations."/_matrix".proxyPass = "http://[::1]:8008";

    services.matrix-synapse = {
      database_type = "sqlite3";

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

      # NOTE to self:
      # - /data/synapse/media_store becomes /var/lib/matrix-synapse/media WITHOUT `_store`
      # - /data/synapse/signing.key becomes /var/lib/matrix-synapse/homeserver.signing.key
    };

  };

}
