{ config, pkgs, lib, options, ... }:

with lib;

let

  cfg = config.my.services.cgit;

in {

  options.my.services.cgit = {
    domainName = mkOption {
      default = null;
      description = "domain name for CGit (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {
    services.cgit.${cfg.domainName} = {
      enable = true;
      scanPath = "/var/lib/cgit";
      settings = {
        branch-sort = "age";
        enable-index-links = 1;
        enable-commit-graph = 1;
        enable-log-filecount = 1;
        enable-log-linecount = 1;
        readme = ":README.md";
        snapshots = "tar.gz";
      };
    };

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;
    };
  };

}
