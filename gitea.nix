# This module deploys Gitea.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.gitea;
  internalListenPort = 17610;

  ldapOptions = let
    inherit (config.my) ldap;
  in {
    name = "auto-ldap";
    security-protocol = "LDAPS";
    host = ldap.domainName;
    port = "636"; # LDAPS
    user-search-base = "ou=users,${ldap.suffix}";
    user-filter = "(&(uid=%s)(isMemberOf=cn=gitea-users,ou=groups,${ldap.suffix}))";
    admin-filter = "(isMemberOf=cn=gitea-admins,ou=groups,${ldap.suffix})";
    username-attribute = "uid";
    firstname-attribute = "givenName";
    surname-attribute = "sn";
    email-attribute = "mail";
    bind-dn = "uid=${ldap.searchUserName},ou=users,${ldap.suffix}";
    bind-password = ldap.searchUserPassword;
  };

  ldapFlags = "--attributes-in-bind --synchronize-users";

in {

  config = mkIf cfg.enable {

    services.gitea = {
      disableRegistration = true;

      rootUrl = "https://${cfg.domain}/";
      httpAddress = "127.0.0.1";
      httpPort = internalListenPort;

      # NOTE: default log mode is "console" since Gitea 1.9
      log.level = "Info";

      # security/privacy hardening
      settings = {
        "repository.upload" = {
          ENABLED = false;
        };

        # reject insecure keys
        "ssh.minimum_key_sizes" = {
          DSA = -1;
          ECDSA = -1;
          ED25519 = 256;
          RSA = 4096;
        };

        "service" = {
          REQUIRE_SIGNIN_VIEW = true;
        };

        "picture" = {
          DISABLE_GRAVATAR = true;
        };

        "api" = {
          ENABLE_SWAGGER = false;
        };

        "oauth2" = {
          ENABLE = false;
        };

        # enable user sync job for LDAP
        "cron.sync_external_users" = {
          RUN_AT_START = true;
          SCHEDULE = "@every 1h";
          UPDATE_EXISTING = true;
        };
      };
    };

    # LDAP authentication cannot be set up declaratively, so we have to do it
    # at the end of the preStart script
    #
    # WARNING: This assumes that the LDAP auth source has the internal ID 1.
    systemd.services.gitea.preStart = let
      giteaBin = "${pkgs.gitea}/bin/gitea";

      formatOption = key: value: "--${key} ${escapeShellArg value}";
      ldapOptionsStrs = mapAttrsToList formatOption ldapOptions;
      ldapOptionsStr = concatStringsSep " " ldapOptionsStrs;
    in mkAfter ''
      if ${giteaBin} admin auth list | grep -q ${ldapOptions.name}; then
        ${giteaBin} admin auth update-ldap --id 1 ${ldapOptionsStr} ${ldapFlags}
      else
        ${giteaBin} admin auth add-ldap ${ldapOptionsStr} ${ldapFlags}
      fi
    '';

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
        add_header  Content-Security-Policy "default-src 'self' data:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'" always; # Gitea uses inline CSS (ok), inline fonts via data: (well...) and inline JS (shame on you)

        # hamper Google surveillance
        add_header Permissions-Policy "interest-cohort=()" always;
      '';
    };

  };

}
