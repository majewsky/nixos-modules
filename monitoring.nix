# This module configures the Consul agent that is running on every machine for
# service discovery within the monitoring network.
# REPLACES hologram-monitoring-agents
# REPLACES hologram-monitoring-client

{ config, pkgs, lib, ... }:

with lib;

let

  machineID = config.my.machineID;
  cfg = config.my.services.monitoring;

in {

  imports = [
    /nix/my/unpacked/generated-consul.nix        # supplies more services.consul.extraConfig
    /nix/my/unpacked/generated-wg-monitoring.nix # supplies config.my.services.monitoring
  ];

  options.my.services.monitoring.network = {

    enableClient = mkOption {
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

  config = {

    ############################################################################
    # overlay network for monitoring using Wireguard

    networking.wireguard.interfaces."wg-monitoring" = lib.mkIf cfg.network.enableClient {
      ips = [ "${cfg.network.slash24}.${toString machineID}/24" ];
      peers = [{
        allowedIPs = [ "${cfg.network.slash24}.0/24" ];
        endpoint = "${cfg.network.server.endpoint}";
        publicKey = "${cfg.network.server.publicKey}";
        presharedKeyFile = toString /nix/my/unpacked/generated-wg-monitoring-psk;
        persistentKeepalive = 25;
      }];
      privateKeyFile = toString /nix/my/unpacked/generated-wg-monitoring-key;
    };

    ############################################################################
    # Consul for service discovery within the monitoring network

    services.consul = {
      package = pkgs.channels.unstable.consul;
      enable = true;
      interface.bind = "wg-monitoring";
      extraConfig = {
        log_level = "INFO";
        server = mkDefault false;
        # The following extraConfig options come from a secret module:
        #   bootstrap, datacenter, encrypt, retry_join
        #   (maybe also server = true)
      };
    };

    # open ports for Consul cluster-internal traffic
    networking.firewall.interfaces."wg-monitoring" = {
      allowedTCPPorts = [ 8300 8301 8302 ];
      allowedUDPPorts = [ 8300 8301 8302 ];
    };

    ############################################################################
    # deploy prometheus-node-exporter

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "${cfg.network.slash24}.${toString machineID}";
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

  };

}
