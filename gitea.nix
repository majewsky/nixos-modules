# This module deploys Gitea.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.gitea;
  internalListenPort = 17610;

in {

  config = mkIf cfg.enable {

    services.gitea = {
      disableRegistration = true;

      rootUrl = "https://${cfg.domain}/";
      httpAddress = "127.0.0.1";
      httpPort = internalListenPort;

      log.level = "Info";
      log.rootPath = "/var/lib/gitea/log"; # TODO should be /var/log/gitea, but the NixOS module for Gitea does not set that path up

      # security/privacy hardening
      extraConfig = ''
        [repository.upload]
        ENABLED = false

        [ssh.minimum_key_sizes]
        ; reject insecure keys
        DSA     = -1
        ECDSA   = -1
        ED25519 = 256
        RSA     = 4096

        [service]
        REQUIRE_SIGNIN_VIEW = true

        [picture]
        DISABLE_GRAVATAR = true

        [api]
        ENABLE_SWAGGER = false

        [oauth2]
        ENABLE = false
      '';
    };

    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      enableACME = true;

      locations."/".proxyPass = "http://127.0.0.1:${toString internalListenPort}/";

      extraConfig = ''
        # recommended HTTP headers according to https://securityheaders.io
        # NOTE: Gitea already does X-Frame-Options, so we don't need to
        add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always; # six months
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Feature-Policy "accelerometer 'none', ambient-light-sensor 'none', autoplay 'none', camera 'none', document-domain 'none', encrypted-media 'none', fullscreen 'none', geolocation 'none', gyroscope 'none', magnetometer 'none', microphone 'none', midi 'none', payment 'none', picture-in-picture 'none', sync-xhr 'none', usb 'none', vibrate 'none', vr 'none'" always;
        add_header  Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline'" always; # Gitea uses inline CSS
      '';
    };

  };

}
