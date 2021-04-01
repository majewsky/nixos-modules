# This module enables a very frugal, trivially GDPR-compliant access log on
# selected nginx virtual hosts. The log only contains the URL path and the user
# agent. That's enough to do access statistics, but does not contain any PII.

{ config, pkgs, lib, options, ... }:

with lib;

let

  cfg = config.my.services.nginx;

in {

  options.my.services.nginx.domainsWithAccessLog = mkOption {
    description = "list of domain names for which nginx will write a minimal access log";
    default = [];
    type = types.listOf types.str;
  };

  config = mkIf (cfg.domainsWithAccessLog != []) {
    services.nginx.commonHttpConfig = ''
      map $status $loggable {
        ~^[23]  1;
        default 0;
      }
      log_format gdpr-compliant '[$time_iso8601] "$host$uri"';
    '';

    services.nginx.virtualHosts = genAttrs cfg.domainsWithAccessLog (domainName: {
      extraConfig = ''
        access_log /var/log/nginx/access.log gdpr-compliant if=$loggable;
      '';
    });
  };
}
