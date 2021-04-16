# This module is used by all machines with static websites that do NOT come from Git repos.
# REPLACES hologram-nginx

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.plainweb;

  optionsPerWebsite = {
    docroot = mkOption {
      description = "the directory where the website contents are stored";
      type = types.str;
    };

    directoryListings = mkOption {
      description = "whether to generate directory listings";
      default = true;
      type = types.bool;
    };

    onlySSL = mkOption {
      description = "whether to upgrade all HTTP connections to HTTPS through 301 responses";
      default = true;
      type = types.bool;
    };
  };

in {

  options.my.services.plainweb.sites = mkOption {
    description = "static websites that are NOT served from Git repos";
    example = {
      "doc.example.com" = {
        docroot = "/var/lib/example.com";
        directoryListings = true;
      };
    };
    default = {};
    type = with types; attrsOf (submodule { options = optionsPerWebsite; });
  };

  config = mkIf (cfg.sites != {}) {

    services.nginx.virtualHosts = mapAttrs (domainName: domainOpts: {
      addSSL = !domainOpts.onlySSL;
      forceSSL = domainOpts.onlySSL;
      enableACME = true;

      locations."/".root = "${domainOpts.docroot}";

      # for TLDs like example.com, support the alias www.example.com
      serverAliases = if (builtins.length (splitString "." domainName)) == 2 then [ "www.${domainName}" ] else [];

      extraConfig = ''
        charset utf-8;

        # recommended HTTP headers according to https://securityheaders.io
        add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always; # six months
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Feature-Policy "accelerometer 'none', ambient-light-sensor 'none', autoplay 'none', camera 'none', document-domain 'none', encrypted-media 'none', fullscreen 'none', geolocation 'none', gyroscope 'none', magnetometer 'none', microphone 'none', midi 'none', payment 'none', picture-in-picture 'none', sync-xhr 'none', usb 'none', vibrate 'none', vr 'none'" always;

        # CSP includes unsafe-inline to allow <style> tags in hand-written HTML
        add_header Content-Security-Policy "default-src 'self' 'unsafe-inline'; img-src 'self' data:;" always;

        # hamper Google surveillance
        add_header Permissions-Policy "interest-cohort=()" always;

        ${optionalString domainOpts.directoryListings "autoindex on;"}
      '';
    }) cfg.sites;

  };

}
