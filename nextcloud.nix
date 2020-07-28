# This module configures a NextCloud instance.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.my.services.nextcloud;

  internalListenPort = 21147;

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
      locations."/".proxyPass = "http://[::1]:${toString internalListenPort}";
    };
  };

}
