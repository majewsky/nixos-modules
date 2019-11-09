# This module contains the parts of the Portunus configuration that can be
# upstreamed into nixpkgs.
# TODO upstream this into nixpkgs
# TODO options for TLS (ACME support?)

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.portunus;
  portunusPackage = pkgs.callPackage ./pkgs/portunus/default.nix {};

in {

  options.services.portunus = {
    enable = mkEnableOption "Portunus, a self-contained user/group management and authentication service";

    stateDirectory = mkOption {
      description = "Path where Portunus stores its state. Remember to make regular backups of this directory.";
      default = "/var/lib/portunus";
      type = types.str;
    };

    listenPort = mkOption {
      description = "Port where the Portunus webserver is listening. You need to reverse-proxy this through a TLS-capable webserver, so Portunus' webserver only listens on localhost.";
      default = 8080;
      type = types.ints.u16;
    };

    package = mkOption {
      default = portunusPackage;
      defaultText = "pkgs.portunus";
      description = "Package containing the Portunus binaries.";
      type = types.package;
    };

    user = mkOption {
      description = "User account under which Portunus runs its webserver.";
      default = "portunus";
      type = types.str;
    };

    group = mkOption {
      description = "Group account under which Portunus runs its webserver.";
      default = "portunus";
      type = types.str;
    };

    ldap = {
      suffix = mkOption {
        description = "The DN of the topmost entry in your LDAP directory.";
        example = "dc=example,dc=org";
        type = types.str;
      };

      package = mkOption {
        default = pkgs.openldap;
        defaultText = "pkgs.openldap";
        description = "Package containing the OpenLDAP server binary.";
        type = types.package;
      };

      user = mkOption {
        description = "User account under which Portunus runs its LDAP server.";
        default = "openldap";
        type = types.str;
      };

      group = mkOption {
        description = "Group account under which Portunus runs its LDAP server.";
        default = "openldap";
        type = types.str;
      };
    };

  };

  config = mkIf cfg.enable {

    users.users.openldap = mkIf (cfg.ldap.user == "openldap") {
      name  = cfg.ldap.user;
      group = cfg.ldap.group;
      uid   = config.ids.uids.openldap;
    };
    users.groups.openldap = mkIf (cfg.ldap.user == "openldap") {
      name  = cfg.ldap.group;
      gid   = config.ids.gids.openldap;
    };

    users.users.portunus = mkIf (cfg.user == "portunus") {
      name  = cfg.user;
      group = cfg.group;
    # uid   = config.ids.uids.portunus;
    };
    users.groups.portunus = mkIf (cfg.user == "portunus") {
      name  = cfg.group;
    # uid   = config.ids.gids.portunus;
    };

    # make ldapsearch(1) etc. available in interactive shells
    environment.systemPackages = [ cfg.ldap.package ];

    systemd.services.portunus = {
      description = "Self-contained authentication service";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        # in my setup, Portunus will fail to start up unless the WireGuard network
        # is already up, because ldap-client.nix overrides the LDAP server's domain
        # name to refer to an address on the WireGuard network
        "wireguard-wg-monitoring.service"
      ];

      serviceConfig.ExecStart = "${cfg.package.out}/bin/portunus-orchestrator";
      environment = {
        PORTUNUS_LDAP_SUFFIX = cfg.ldap.suffix;
        PORTUNUS_SERVER_BINARY = "${cfg.package.out}/bin/portunus-server";
        PORTUNUS_SERVER_GROUP = cfg.group;
        PORTUNUS_SERVER_USER = cfg.user;
        PORTUNUS_SERVER_HTTP_LISTEN = "[::1]:${toString cfg.listenPort}";
        PORTUNUS_SERVER_STATE_DIR = cfg.stateDirectory;
        PORTUNUS_SLAPD_BINARY = "${cfg.ldap.package.out}/libexec/slapd";
        PORTUNUS_SLAPD_GROUP = cfg.ldap.group;
        PORTUNUS_SLAPD_USER = cfg.ldap.user;
        PORTUNUS_SLAPD_SCHEMA_DIR = "${cfg.ldap.package.out}/etc/schema";
      };
    };

  };

}
