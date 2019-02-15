# This module is imported by every system, both headless servers and workstations.
# REPLACES hologram-base
# REPLACES hologram-openssh
# REPLACES hologram-monitoring-agents
# REPLACES hologram-monitoring-client

{ config, pkgs, lib, ... }:

let
  cfg = config.majewsky.base;
in

with lib; {

  imports = [
    /nix/my/unpacked/generated-basic.nix # supplies machineID and hostname
    /nix/my/unpacked/generated-consul.nix # supplies more services.consul.extraConfig
    /nix/my/unpacked/generated-wg-monitoring.nix # supplies monitoringNetwork options
  ];

  options.majewsky.base = {
    machineID = mkOption {
      description = "machine ID (appears in autogenerated IP addresses etc.)";
      type = types.ints.u8;
    };
    fqdn = mkOption {
      description = "fully-qualified domain name for this machine (only when that FQDN is world-resolvable in DNS)";
      default = null;
      type = types.nullOr types.string;
    };

    monitoringNetwork = {
      enable = mkOption {
        default = false;
        description = "whether to set up the wg-monitoring interface with the client configuration";
        type = types.bool;
      };

      slash24 = mkOption {
        description = "network part of wg-monitoring interface address";
        type = types.string;
      };

      server.endpoint = mkOption {
        description = "host:port address of wg-monitoring server";
        type = types.string;
      };
      server.publicKey = mkOption {
        description = "public key of wg-monitoring server";
        type = types.string;
      };
    };

    consul.isServer = mkOption {
      default = false;
      description = "whether this machine is a server (or just a client) in the Consul cluster";
      type = types.bool;
    };
  };

  options.majewsky.git = {
    userName = mkOption {
      default = "Stefan Majewsky";
      description = "value of user.name in /etc/gitconfig";
      type = types.string;
    };
    userEMail = mkOption {
      default = "majewsky@gmx.net";
      description = "value of user.email in /etc/gitconfig";
      type = types.string;
    };
  };

  config = {
    ############################################################################
    # package overrides (copy-pasted from j03, thx!)

    nixpkgs.config.packageOverrides = pkgs: {
      channels = {
        # It seems like numeric channel names are not updated correctly to
        #   /nix/var/nix/profiles/per-user/root/channels/
        # when using:
        #   nixos-rebuild switch --upgrade
        # however this works:
        #   nix-channel --update

        ## nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable
        unstable = import <nixos-unstable>
          { config = config.nixpkgs.config; };
        ## nix-channel --add https://nixos.org/channels/nixos-18.09 nixos-eighteen-nine
        # nix1809 = import <nixos-eighteen-nine>
        #   { config = config.nixpkgs.config; };
      };
    };

    ############################################################################
    # basic setup for interactive use

    system.autoUpgrade.enable = mkDefault true;

    environment.systemPackages = with pkgs; [
      (pkgs.callPackage ./pkgs/bootstrap-devenv/default.nix {})
      (pkgs.callPackage ./pkgs/gofu/default.nix {})
      dnsutils # dig(1), host(1)
      git
      gnumake # for decrypting the secrets in this repo
      gnupg   # for decrypting the secrets in this repo
      gptfdisk
      jq
      lsof
      nmap # ncat(1)
      pv
      ripgrep
      rsync
      screen
      strace
      tcpdump
      traceroute
      tree
      units
      vim
      wget
      zsh
    ];

    i18n = {
      consoleFont = "Lat2-Terminus16";
      consoleKeyMap = "us";
      defaultLocale = "de_DE.UTF-8";
      supportedLocales = [ "de_DE.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
    };

    time.timeZone = "Europe/Berlin";
    services.timesyncd.servers = [ "ptbtime1.ptb.de" ];

    boot.tmpOnTmpfs = true;
    services.openssh.enable = true;

    users.users.stefan = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = ["wheel"];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keyFiles = [ /nix/my/unpacked/ssh-keys ];
    };

    programs.zsh = {
      # make zsh work as a login shell; cf. https://github.com/NixOS/nixpkgs/issues/20548
      enable = true;

      # use my own prompt
      promptInit = "";
    };

    # silence Git's complaints about missing identity
    environment.etc."gitconfig".text = ''
      [user]
      name = ${config.majewsky.git.userName}
      email = ${config.majewsky.git.userEMail}
    '';

    # workaround for https://github.com/NixOS/nixpkgs/issues/47580 which will
    # be fixed in 19.03
    networking.firewall.interfaces.default = mkIf (config.system.stateVersion == "18.09") {
      allowedTCPPorts      = config.networking.firewall.allowedTCPPorts;
      allowedTCPPortRanges = config.networking.firewall.allowedTCPPortRanges;
      allowedUDPPorts      = config.networking.firewall.allowedUDPPorts;
      allowedUDPPortRanges = config.networking.firewall.allowedUDPPortRanges;
    };

    ############################################################################
    # overlay network for monitoring using Wireguard

    networking.wireguard.interfaces."wg-monitoring" = lib.mkIf cfg.monitoringNetwork.enable {
      ips = [ "${cfg.monitoringNetwork.slash24}.${toString cfg.machineID}/24" ];
      peers = [{
        allowedIPs = [ "${cfg.monitoringNetwork.slash24}.0/24" ];
        endpoint = "${cfg.monitoringNetwork.server.endpoint}";
        publicKey = "${cfg.monitoringNetwork.server.publicKey}";
        presharedKeyFile = toString /nix/my/unpacked/generated-wg-monitoring-psk;
        persistentKeepalive = 25;
      }];
      privateKeyFile = toString /nix/my/unpacked/generated-wg-monitoring-key;
    };

    ############################################################################
    # Consul for service discovery within the monitoring network

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "${cfg.monitoringNetwork.slash24}.${toString cfg.machineID}";
      disabledCollectors = [ "wifi" ];
      openFirewall = true;
      firewallFilter = "-i wg-monitoring -p tcp -m tcp --dport 9100";
    };

    # TODO add this to systemd.services.consul.restartTriggers
    environment.etc."consul.d/prometheus-node-exporter.json".text = ''
      {
        "service": {
          "name": "prometheus-node-exporter",
          "port": 9100,
          "tags": [ "prometheus" ],
          "meta": {}
        }
      }
    '';

    ############################################################################
    # Consul for service discovery within the monitoring network

    services.consul = {
      package = pkgs.channels.unstable.consul;
      enable = true;
      interface.bind = "wg-monitoring";
      extraConfig = {
        log_level = "INFO";
        server = cfg.consul.isServer;
        # The following extraConfig options come from a secret module:
        #   bootstrap, datacenter, encrypt, retry_join
      };
    };

    # open ports for Consul cluster-internal traffic
    networking.firewall.interfaces."wg-monitoring" = {
      allowedTCPPorts = [ 8300 8301 8302 ];
      allowedUDPPorts = [ 8300 8301 8302 ];
    };

    ############################################################################
    # base nginx configuration for servers that have it

    services.nginx = mkIf (config.majewsky.base.fqdn != null) {
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
      '';

      virtualHosts = nameValuePair config.majewsky.base.fqdn {
        default = true;
        forceSSL = true;
        enableACME = true;
      };
    };

  };

}
