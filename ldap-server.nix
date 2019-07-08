# This module deploys an LDAP server using Portunus.
{ config, pkgs, lib, options, ... }:

with lib;

let

  cfg = config.my.services.portunus;

  internalListenPort = 18693;

in {

  imports = [ ./portunus.nix ];

  options.my.services.portunus = {
    domainName = mkOption {
      default = null;
      description = "domain name for Portunus (must be given to enable the service)";
      type = types.nullOr types.str;
    };

    ldapDomainName = mkOption {
      description = "domain name for the LDAP server";
      type = types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    services.portunus = {
      enable = true;
      listenPort = internalListenPort;
    };

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://[::1]:${toString internalListenPort}";
    };

    # TODO: give this cert to Portunus
    security.acme.certs.${cfg.ldapDomainName} = {
      webroot = "/var/lib/acme/acme-challenge"; # TODO pull this value from default of services.nginx.virtualHosts.<name>.acmeRoot
      postRun = ''
        systemctl restart portunus.service
      '';
    };

    # allow access to LDAP port (TODO LDAPS)
    networking.firewall.interfaces.wg-monitoring.allowedTCPPorts = [ 389 ];

  };

}
