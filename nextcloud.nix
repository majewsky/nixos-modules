# This module configures a NextCloud instance.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.my.services.nextcloud;

in {

  options.my.services.nextcloud = {
    domainName = mkOption {
      default = null;
      description = "domain name for NextCloud (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;

      extraConfig = ''
        add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always; # six months
      '';
      # NOTE: the rest is configured by services.nextcloud.enable
    };

    services.nextcloud = {
      enable = true;
      hostName = cfg.domainName;
      package = pkgs.nextcloud27;

      database.createLocally = true;

      # NOTE: services.nextcloud.config is only used for the initial setup, afterwards Nextcloud's stateful config takes precedence
      config = {
        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbname = "nextcloud";
        adminpassFile = toString /var/lib/nextcloud-root-password;
        adminuser = "root";
        overwriteProtocol = "https";
        defaultPhoneRegion = "DE";
      };
    };

    services.postgresql = {
      package = pkgs.postgresql_16;
      dataDir = "/var/lib/postgresql/16";
    };

  };

}
