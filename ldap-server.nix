# This module deploys an LDAP server using Portunus.
{ config, pkgs, lib, options, ... }:

with lib;

let

  cfg = config.my.services.portunus;

  internalListenPorts = { portunus = 18693; dex = 18694; };

  oidcClientIDs = [ "matrix-synapse" ];

  dstRootCA_X3 = pkgs.writeText "dst-root-ca-x3.pem" ''
    -----BEGIN CERTIFICATE-----
    MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
    MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
    DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
    PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
    Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
    AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
    rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
    OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
    xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
    7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
    aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
    HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
    SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
    ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
    AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
    R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
    JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
    Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
    -----END CERTIFICATE-----
  '';

in {

  imports = [
    ./portunus.nix
    /nix/my/unpacked/generated-oidc-config.nix
  ];

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

  options.my.services.oidc.clientSecrets = genAttrs oidcClientIDs (clientID: mkOption {
    description = "client secret for OIDC client ${clientID}";
    type = types.str;
  });

  config = mkIf (cfg.domainName != null) {

    ############################################################################
    # Portunus

    services.portunus = {
      enable = true;
      listenPort = internalListenPorts.portunus;
    };

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://[::1]:${toString internalListenPorts.portunus}";
      locations."/dex/".proxyPass = "http://127.0.0.1:${toString internalListenPorts.dex}/dex/";
    };

    ############################################################################
    # LDAPS

    # to get an ACME cert, we need to add a dummy vhost to the nginx config
    services.nginx.virtualHosts.${cfg.ldapDomainName} = mkDefault {
      forceSSL = true;
      enableACME = true;
      locations."/".extraConfig = ''
        deny all;
        return 404;
      '';
    };
    security.acme.certs.${cfg.ldapDomainName}.postRun = ''
      cat ${dstRootCA_X3} chain.pem > complete-chain.pem
      systemctl restart portunus.service
    '';

    systemd.services.portunus = let
      acmeDirectory = "/var/lib/acme/${cfg.ldapDomainName}";
    in {
      environment = {
        PORTUNUS_SLAPD_TLS_CA_CERTIFICATE = "${acmeDirectory}/complete-chain.pem";
        PORTUNUS_SLAPD_TLS_CERTIFICATE    = "${acmeDirectory}/cert.pem";
        PORTUNUS_SLAPD_TLS_DOMAIN_NAME    = cfg.ldapDomainName;
        PORTUNUS_SLAPD_TLS_PRIVATE_KEY    = "${acmeDirectory}/key.pem";
      };
    };

    # allow access to LDAPS port
    networking.firewall.interfaces.wg-monitoring.allowedTCPPorts = [ 636 ];

    ############################################################################
    # OIDC with Dex

    services.dex.enable = true;
    services.dex.settings = {
      # HTTP config
      issuer = "https://${cfg.domainName}/dex";
      web.http = "127.0.0.1:${toString internalListenPorts.dex}";

      # storage backend
      storage = {
        type = "sqlite3";
        config.file = "/var/lib/dex/dex.db";
      };

      # connectors
      enablePasswordDB = false;
      connectors = [{
        type = "ldap";
        id = "ldap";
        name = "LDAP";
        config = let clientCfg = config.my.ldap; in {
          host = "${clientCfg.domainName}:636";
          bindDN = "uid=${clientCfg.searchUserName},ou=users,${clientCfg.suffix}";
          bindPW = config.my.ldap.searchUserPassword;
          userSearch = {
            baseDN = "ou=users,${clientCfg.suffix}";
            filter = "(objectclass=person)";
            username = "uid";
            idAttr = "uid";
            emailAttr = "mail";
            nameAttr = "cn";
          };
          groupSearch = {
            baseDN = "ou=groups,${clientCfg.suffix}";
            filter = "(objectclass=groupOfNames)";
            nameAttr = "cn";
            userMatchers = [{ userAttr = "dn"; groupAttr = "member"; }];
          };
        };
      }];

      # NOTE: staticClients are added via secrets
    };

    systemd.services.dex.serviceConfig = {
      # `dex.service` is super locked down out of the box, but we need some
      # place to write the SQLite database. This creates $STATE_DIRECTORY below
      # /var/lib/private because DynamicUser=true, but it gets symlinked into
      # /var/lib/dex inside the unit, so the config as above works.
      StateDirectory = "dex";
    };

  };

}
