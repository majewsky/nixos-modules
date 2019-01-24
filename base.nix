# This module is imported by every system, both headless servers and workstations.

{ config, pkgs, lib, ... }:

let
  cfg = config.majewsky.base;
in

with lib; {

  imports = [
    /nix/my/secrets/generated-basic.nix # supplies machineID and hostname
    /nix/my/secrets/generated-consul.nix # supplies more services.consul.extraConfig
    /nix/my/secrets/generated-wg-monitoring.nix # supplies monitoringNetwork options
  ];

  options.majewsky.base = {
    machineID = mkOption {
      description = "machine ID (appears in autogenerated IP addresses etc.)";
      type = types.ints.u8;
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

    environment.systemPackages = with pkgs; [
      # TODO gofu
      # TODO bootstrap-devenv
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
    };

    boot.tmpOnTmpfs = true;
    time.timeZone = "Europe/Berlin";
    services.openssh.enable = true;

    users.users.stefan = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keyFiles = [ /nix/my/secrets/ssh-keys ];
    };

    # silence Git's complaints about missing identity
    environment.etc."gitconfig".text = ''
      [user]
      name = Fake
      email = fake@example.com
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
        presharedKeyFile = "/nix/my/secrets/generated-wg-monitoring-psk";
        persistentKeepalive = 25;
      }];
      privateKeyFile = "/nix/my/secrets/generated-wg-monitoring-key";
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

  };

}
