# This module contains basic configuration for nginx, including the firewall
# port opening. It is only active on servers that have a globally resolvable
# FQDN.
# REPLACES hologram-nginx

{ config, pkgs, lib, options, ... }:

with lib;

let

  cfg = config.my.services.nginx;

in {

  options.my.services.nginx = {
    fqdn = mkOption {
      description = "fully-qualified domain name for this machine (presence enables nginx)";
      default = null;
      type = types.nullOr types.str;
    };

    fqdnLocations = mkOption {
      description = "extra location blocks that get added to the virtual host corresponding to the FQDN (this is where infrastructure services without their own domain can be mounted)";
      default = {};
      type = (builtins.head (builtins.head options.services.nginx.virtualHosts.type.getSubModules).imports).options.locations.type;
    };
  };

  config = mkIf (cfg.fqdn != null) {

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx = {
      enable = true;

      package = pkgs.nginxMainline;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # Datensparsamkeit: do not log any requests (or "File not found" errors
      # resulting from GET on unknown URLs)
      appendHttpConfig = ''
        access_log off;
        error_log stderr crit;

        proxy_headers_hash_bucket_size 128;

        # obstruct Google surveillance
        add_header Permissions-Policy "interest-cohort=()" always;
      '';

      virtualHosts."${cfg.fqdn}" = {
        default = true;
        forceSSL = true;
        enableACME = true;
        locations = cfg.fqdnLocations;
      };
    };

    # extra hardening (most hardening is in the upstream module at this point)
    systemd.services.nginx.serviceConfig = {
      ReadWritePaths = "/var/spool/nginx /var/log/nginx";
    };

    users.users.stefan.extraGroups = [ "nginx" ]; # to read access logs

  };

}
