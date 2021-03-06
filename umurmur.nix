# This module configures a Mumble server using umurmur.
# REPLACES hologram-murmur
{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.umurmur;

  configFile = pkgs.writeText "umurmurd.conf" ''
    max_bandwidth = 128000;
    welcometext   = "${cfg.welcomeText}";
    certificate   = "/var/lib/acme/${cfg.domainName}/fullchain.pem";
    private_key   = "/var/lib/acme/${cfg.domainName}/key.pem";
    ca_path       = "/etc/ssl/certs/";

    ${lib.optionalString (cfg.password != null) ''
    password          = "${cfg.password}";
    ''}
    allow_textmessage = true;
    opus_threshold    = 100;
    show_addresses    = false;
    max_users         = 20;
    ${lib.optionalString (cfg.adminPassword != null) ''
    admin_password    = "${cfg.adminPassword}";
    ban_length        = 0;
    enable_ban        = true;
    banfile           = "/var/lib/umurmur/banfile.txt";
    sync_banfile      = true;
    ''}

    bindport  = ${toString cfg.listenPort};
    bindport6 = ${toString cfg.listenPort};

    channels = (
      {
        name = "Root";
        parent = "";
        description = "Root channel. No entry.";
        noenter = true;
      }
      ,{
        name = "Lobby";
        parent = "Root";
        description = "Lobby channel (default).";
      }
    );

    default_channel = "Lobby";

    username  = "umurmur";
    groupname = "umurmur";
  '';

in {

  options.my.services.umurmur = {
    # The `domainName` option is the only required configuration option (we
    # need a domain name for getting a TLS cert with ACME), so it takes the
    # role of `enable`.
    domainName = mkOption {
      default = null;
      description = "domain name for the uMurmur server for Mumble (must be given to enable the service)";
      type = types.nullOr types.str;
    };

    listenPort = mkOption {
      default = 64738;
      description = "the port where uMurmur is listening";
      type = types.ints.u16;
    };
    openFirewall = mkOption {
      default = true;
      description = "whether to open the uMurmur listen port in the firewall";
      type = types.bool;
    };

    welcomeText = mkOption {
      default = "Welcome to uMurmur!";
      description = "welcome message for connected clients";
      type = types.str;
    };
    password = mkOption {
      default = null;
      description = "password for the uMurmur server";
      type = types.nullOr types.str;
    };
    adminPassword = mkOption {
      default = null;
      description = "admin password for the uMurmur server (if not given, administrative functions such as banning are disabled)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {
    users.groups.umurmur = {};
    users.users.umurmur = {
      description     = "Murmur Service user";
      group           = "umurmur";
      home            = "/var/lib/umurmur";
      createHome      = true;
    };

    # to get an ACME cert, we need to add a dummy vhost to the nginx config
    services.nginx.virtualHosts.${cfg.domainName} = mkDefault {
      forceSSL = true;
      enableACME = true;
      locations."/".extraConfig = ''
        deny all;
        return 404;
      '';
    };
    security.acme.certs.${cfg.domainName} = {
      allowKeysForGroup = true;
      group = "umurmur";
      keyType = "rsa4096"; # https://github.com/umurmur/umurmur/issues/147
      postRun = "systemctl restart umurmur.service";
    };

    systemd.services.umurmur = {
      description = "Mumble server";
      requires = [ "network-online.target" ];
      after = [ "network.target" "network-online.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.umurmur}/bin/umurmurd -d -r -c ${configFile}";
        User = "umurmur";
        Group = "umurmur";
      };

      wantedBy = [ "multi-user.target" ];
    };
    my.hardening.umurmur = {
      allowInternetAccess = true; # to bind Murmur
    };

    # open port in firewall
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.listenPort];
    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [cfg.listenPort];

  };

}
