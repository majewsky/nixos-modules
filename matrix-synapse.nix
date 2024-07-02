# This module is used by the machine that runs my Matrix homeserver.
# REPLACES hologram-bethselamin-synapse
{ config, lib, pkgs, ... }:

with lib;

let

  fqdn = config.my.services.nginx.fqdn;
  cfg = config.services.matrix-synapse;

in {

  # To enable this module, the machine's configuration.nix must set:
  # - config.services.matrix-synapse.enable
  # - config.services.matrix-synapse.settings.server_name
  # - config.services.matrix-synapse.settings.macaroon_secret_key
  config = mkIf (cfg.enable) {

    networking.firewall.allowedTCPPorts = [ 8448 ];

    services.nginx.virtualHosts.${cfg.settings.server_name} = {
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
      locations."/_synapse".proxyPass = "http://[::1]:8008";
    };

    services.matrix-synapse.settings = {
      database.name = "sqlite3";

      listeners = [
        {
          port = 8008;
          bind_addresses = [ "::1" ];
          resources = [ { compress = false;  names = [ "client" "federation" ]; } ];
          type = "http";
          tls = false;
          x_forwarded = true;
        }
      ];

      allow_guest_access = false;
      enable_registration = false;
      media_store_path = "${cfg.dataDir}/media"; # TODO move to new default `$dataDir/media_store`

      oidc_providers = [{
        idp_id = "dex";
        idp_name = "SSO via ${config.my.services.portunus.domainName}";
        issuer = "https://${config.my.services.portunus.domainName}/dex";
        client_id = "matrix-synapse";
        client_secret = config.my.services.oidc.clientSecrets.matrix-synapse;
        scopes = [ "openid" "profile" "groups" ];
        user_mapping_provider.config = {
          localpart_template = "{{ user.preferred_username }}";
          display_name_template = "{{ user.name }}";
        };
        attribute_requirements = [{
          attribute = "groups";
          value = "matrix-users";
        }];
        allow_existing_users = true;
      }];
    };
    # TODO: hardening

  };

}
