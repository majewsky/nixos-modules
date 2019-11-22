# This module deploys the Alltag issue tracker.

{ config, pkgs, lib, ... }:

with lib;

let

  alltag = pkgs.callPackage ./pkgs/alltag/default.nix {};

  cfg = config.my.services.alltag;

  internalListenPort = 19826;

in {

  options.my.services.alltag = {
    domainName = mkOption {
      default = null;
      description = "domain name for Alltag (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    users.groups.alltag = {};
    users.users.alltag = {
      group = "alltag";
    };

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString internalListenPort}";
    };

    services.postgresql = {
      enable = true;
      dataDir = "/var/lib/postgresql";
      package = pkgs.postgresql_11;
      initialScript = pkgs.writeText "alltag-postgres-init.sql" ''
        CREATE USER alltag;
        CREATE DATABASE alltag OWNER alltag ENCODING 'utf-8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0;
      '';
    };

    systemd.services.alltag = {
      description = "The ADHD-friendly issue tracker";
      wantedBy = [ "multi-user.target" ];
      after = [ "postgresql.service" ];

      serviceConfig = {
        ExecStart = "${alltag.out}/bin/alltag";
        Restart = "always";
        RestartSec = "10s";

        User = "alltag";
        Group = "alltag";

        # hardening: this process is only supposed to
        #   a) listen on its HTTP socket
        #   b) connect to LDAP via TCP
        #   c) connect to Postgres via AF_UNIX
        LockPersonality = "yes";
        MemoryDenyWriteExecute = "yes";
        NoNewPrivileges = "yes";
        PrivateDevices = "yes";
        PrivateTmp = "yes";
        ProtectControlGroups = "yes";
        ProtectHome = "yes";
        ProtectHostname = "yes";
        ProtectKernelModules = "yes";
        ProtectKernelTunables = "yes";
        ProtectSystem = "strict";
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        RestrictNamespaces = "yes";
        RestrictRealtime = "yes";
        RestrictSUIDSGID = "yes";
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = "@system-service";
      };

      environment = let
        ldap = config.my.ldap;
      in {
        ALLTAG_DB_URI = "postgres:///alltag?host=/run/postgresql&sslmode=disable";
        ALLTAG_LDAP_URI = "ldaps://${ldap.domainName}";
        ALLTAG_LDAP_BIND_DN = "uid=${ldap.searchUserName},ou=users,${ldap.suffix}";
        ALLTAG_LDAP_BIND_PASSWORD = ldap.searchUserPassword;
        ALLTAG_LDAP_SEARCH_BASE_DN = "ou=users,${ldap.suffix}";
        ALLTAG_LDAP_SEARCH_FILTER = "(uid=%%s)";
        ALLTAG_LISTEN_ADDRESS = "127.0.0.1:${toString internalListenPort}";
      };
    };

  };

}
