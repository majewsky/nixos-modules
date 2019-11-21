# This module configures the WireGuard-based monitoring network and the
# monitoring agents that are running on every machine.
# REPLACES hologram-monitoring-agents
# REPLACES hologram-monitoring-client
# REPLACES hologram-monitoring-server

{ config, pkgs, lib, ... }:

with lib;

let

  machineID = config.my.machineID;
  cfg = config.my.services.monitoring;

  script2matrix = pkgs.callPackage ./pkgs/script2matrix/default.nix {};
  prometheus-mv-sd = pkgs.callPackage ./pkgs/prometheus-minimum-viable-sd/default.nix {};

  health-check-script = pkgs.writeScriptBin "health-check-script" ''
    #!/usr/bin/env bash

    # until proven otherwise
    SUCCESS=1

    # check `systemctl --failed`
    check_systemctl() {
        systemctl "$@" --failed | sed '/^$/,$d;/loaded units listed/,$d;1d' | cut -d' ' -f2 > /tmp/failed-units
        if grep -q '[a-z]' /tmp/failed-units; then
            echo ":: systemctl $@ lists $(wc -l < /tmp/failed-units) unit(s) in an error state:"
            cat /tmp/failed-units
            rm -f /tmp/failed-units
            return 1
        fi
        rm -f /tmp/failed-units
        return 0
    }

    if ! check_systemctl; then
        SUCCESS=0
    fi
    for CONTAINER_FILENAME in /etc/containers/*.conf; do
        CONTAINER_NAME="$(basename "$CONTAINER_FILENAME" .conf)"
        if [ "$CONTAINER_NAME" != "*" ]; then
            if ! check_systemctl -M "$CONTAINER_NAME"; then
                SUCCESS=0
            fi
        fi
    done

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

  isServer = cfg.network.server.clients != [];
  isClient = !isServer;

  prometheusServices = builtins.map (srv: {
    targets = [ "${cfg.network.slash24}.${toString machineID}:${toString srv.port}" ];
    labels.instance = config.networking.hostName;
    labels.job = srv.name;
  }) cfg.prometheus.services;
  prometheusServicesFile = pkgs.writeText "prometheus-services.json" (builtins.toJSON prometheusServices);

in {

  imports = [
    /nix/my/unpacked/generated-wg-monitoring.nix # supplies config.my.services.monitoring
  ];

  options = let
    mkStrOpt = description: mkOption { inherit description; type = types.str; };
    mkPortOpt = description: mkOption { inherit description; type = types.ints.u16; };
  in {

    my.services.monitoring.network = {
      slash24 = mkStrOpt "network part of wg-monitoring interface address";

      client = {
        serverEndpoint  = mkStrOpt "host:port address of wg-monitoring server";
        serverPublicKey = mkStrOpt "public key of wg-monitoring server";
      };

      server = {
        clients = let
          optsPerClient = {
            publicKey = mkStrOpt "public key of this client";
            ipAddress = mkStrOpt "IP address of this client";
          };
        in mkOption {
          description = "known clients for this wg-monitoring server";
          default = [];
          type = with types; listOf (submodule { options = optsPerClient; });
        };
        listenPort = mkPortOpt "listen port of wg-monitoring server";
      };
    };

    my.services.monitoring.matrix = {
      userName = mkStrOpt "user ID of Matrix user account for this machine";
      target   = mkStrOpt "Matrix room where healthcheck results shall be posted to";
    };

    my.services.monitoring.prometheus = {
      serviceCollectorIP = mkStrOpt "IP address of node which runs the prometheus-minimum-viable-sd collector";
      serviceCollectorPort = mkPortOpt "listen port of prometheus-minimum-viable-sd collector";

      services = let
        optsPerService = {
          name = mkStrOpt "name of service";
          port = mkPortOpt "port where service emits Prometheus metrics on HTTP";
        };
      in mkOption {
        description = "services on this node that emit Prometheus metrics";
        default = [];
        type = with types; listOf (submodule { options = optsPerService; });
      };
    };

  };

  config = {

    ############################################################################
    # overlay network for monitoring using Wireguard

    networking.wireguard.interfaces."wg-monitoring" = let
      ownIP = "${cfg.network.slash24}.${toString machineID}";
    in {
      listenPort = mkIf isServer cfg.network.server.listenPort;
      ips = [ "${ownIP}/24" ];
      peers = if isClient then [{
        # for clients: only one peer (the server)
        allowedIPs = [ "${cfg.network.slash24}.0/24" ];
        endpoint = "${cfg.network.client.serverEndpoint}";
        publicKey = "${cfg.network.client.serverPublicKey}";
        presharedKeyFile = toString /nix/my/unpacked/generated-wg-monitoring-psk;
        persistentKeepalive = 25;
      }] else (
        # for the server: lots of peers (all clients)
        map (clientOpts: {
          allowedIPs = [ "${clientOpts.ipAddress}/32" ];
          publicKey = clientOpts.publicKey;
          presharedKeyFile = toString /nix/my/unpacked/generated-wg-monitoring-psk;
        }) (filter (clientOpts: clientOpts.ipAddress != ownIP) cfg.network.server.clients)
      );
      privateKeyFile = toString /nix/my/unpacked/generated-wg-monitoring-key;
      postSetup = mkIf isServer "${pkgs.procps}/bin/sysctl net.ipv4.conf.wg-monitoring.forwarding=1";
    };

    networking.firewall.allowedUDPPorts = mkIf isServer [ cfg.network.server.listenPort ];

    # enable peers to talk to each other over the monitoring network
    networking.firewall.extraCommands = mkIf isServer ''
      iptables -A FORWARD -m state --state INVALID -j DROP
      iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
      iptables -A FORWARD -i wg-monitoring -o wg-monitoring -j ACCEPT
    '';

    ############################################################################
    # announcement of services that emit Prometheus metrics

    systemd.services.prometheus-minimum-viable-sd-announce = {
      wantedBy = [ "multi-user.target" ];
      description = "Minimum Viable service discovery for Prometheus";

      serviceConfig = {
        ExecStart = "${prometheus-mv-sd}/bin/prometheus-minimum-viable-sd announce ${prometheusServicesFile} ${cfg.prometheus.serviceCollectorIP}:${toString cfg.prometheus.serviceCollectorPort}";
        Restart = "always";
        RestartSec = "10s";

        # hardening: this process is only supposed to connect to read its input
        # file and the announcer's TCP socket
        DynamicUser = "yes";
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
        RestrictAddressFamilies = "AF_INET AF_INET6";
        RestrictNamespaces = "yes";
        RestrictRealtime = "yes";
        RestrictSUIDSGID = "yes";
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = "@system-service";
      };
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
    # since the listen address refers to the monitoring network, wait until
    # that interface is set up
    systemd.services.prometheus-node-exporter.after = [ "wireguard-wg-monitoring.service" ];

    my.services.monitoring.prometheus.services = [
      { port = 9100; name = "prometheus-node-exporter"; }
    ];

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
