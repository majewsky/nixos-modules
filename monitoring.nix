# This module configures the Consul agent that is running on every machine for
# service discovery within the monitoring network.
# REPLACES hologram-monitoring-agents
# REPLACES hologram-monitoring-client

{ config, pkgs, lib, ... }:

with lib;

let

  machineID = config.my.machineID;
  cfg = config.my.services.monitoring;

  script2matrix = pkgs.callPackage ./pkgs/script2matrix/default.nix {};

  health-check-script = pkgs.writeScriptBin "health-check-script" ''
    #!/usr/bin/env bash

    # until proven otherwise
    SUCCESS=1

    # check `systemctl --failed`
    systemctl --failed | sed '/^$/,$d;/loaded units listed/,$d;1d' | cut -d' ' -f2 > /tmp/failed-units
    if grep -q '[a-z]' /tmp/failed-units; then
        echo ":: systemctl lists $(wc -l < /tmp/failed-units) unit(s) in an error state:"
        cat /tmp/failed-units
        SUCCESS=0
    fi
    rm -f /tmp/failed-units

    # check if auto-upgrade installed a kernel that is not yet booted
    CURRENT_KERNEL="$(tr ' ' '\n' < /proc/cmdline | grep BOOT_IMAGE | sed 's,.*/nix/store/,/nix/store/,')"
    DESIRED_KERNEL="$(readlink -f /run/current-system/kernel)"
    if [ "$CURRENT_KERNEL" != "$DESIRED_KERNEL" ]; then
        echo ":: Reboot is required to activate new kernel."
        echo "current = $CURRENT_KERNEL"
        echo "desired = $DESIRED_KERNEL"
        SUCCESS=0
    fi

    # skip summary for interactive systems if no errors are occurred
    if [ $SUCCESS = 1 ]; then
        if systemctl show display-manager.service 2>/dev/null | grep -q 'SubState=running'; then
            exit 0
        fi
    fi

    # report summary
    if [ $SUCCESS = 0 ]; then
        echo ':: Healthcheck failed.'
    else
        echo ':: Healthcheck completed without errors.'
    fi
    echo "Uptime: $(uptime)"

  '';

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

  options.my.services.monitoring.matrix = {

    userName = mkOption {
      description = "user ID of Matrix user account for this machine";
      type = types.string;
    };
    target = mkOption {
      description = "Matrix room where healthcheck results shall be posted to";
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
      enable = true;
      interface.bind = "wg-monitoring";
      extraConfig = {
        log_level = "INFO";
        # The following extraConfig options come from a secret module:
        #   bootstrap, datacenter, encrypt, retry_join, server
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

    ############################################################################
    # daily health-check that reports to Matrix chat

    systemd.services.auto-health-check = {
      description = "daily health check that reports to Matrix chat";
      requires = [ "network-online.target" ];
      after = [ "network.target" "network-online.target" ];
      path = with pkgs; [ bash script2matrix health-check-script ];
      startAt = "6,18:00:00"; # at 06:00 and 18:00

      environment = {
        MATRIX_USER = cfg.matrix.userName;
        MATRIX_TARGET = cfg.matrix.target;
      };

      script = "exec script2matrix health-check-script";

      serviceConfig = {
        EnvironmentFile = toString /nix/my/unpacked/generated-matrix-password;
      };
    };

    # health check is triggered periodically by `startAt` above, but should
    # also report on reboot
    systemd.timers.auto-health-check.timerConfig.OnStartupSec = "1min";

  };

}
