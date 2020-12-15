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
      # NOTE: the rest is configured by services.nextcloud.enable
    };

    services.postgresql = {
      enable = true;
      dataDir = "/var/lib/postgresql";
      ensureDatabases = [ "nextcloud" ];
      ensureUsers = [{
        name = "nextcloud";
        ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
      }];
    };

    # ensure that postgres is running *before* running the setup
    systemd.services."nextcloud-setup" = {
      requires = ["postgresql.service"];
      after    = ["postgresql.service"];
    };

    services.nextcloud = {
      enable = true;
      hostName = cfg.domainName;
      package = pkgs.nextcloud20;

      # NOTE: services.nextcloud.config is only used for the initial setup, afterwards Nextcloud's stateful config takes precedence
      config = {
        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbhost = "/run/postgresql";
        dbname = "nextcloud";
        adminpassFile = toString /root/nextcloud-root-password;
        adminuser = "root";
      };
    };

  };

}
