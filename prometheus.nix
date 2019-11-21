# This module deploys a two-tiered Prometheus setup:
#
# - The prometheus-collector discovers compatible endpoints and scrapes all
#   metrics from them. It has a short retention time so that the large number
#   of ingested metrics does not consume inappropriately large amounts of disk
#   storage.
# - The prometheus-persister federates selected metrics from the collector and
#   stores them for a long time. This is the datasource of choice for Grafana.

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.prometheus;

  persisterPort = 9090;
  collectorPort = 9091;
  serviceDiscoveryPort = config.my.services.monitoring.prometheus.serviceCollectorPort;

  serviceDiscoveryPackage = pkgs.callPackage ./pkgs/prometheus-minimum-viable-sd/default.nix {};

  collectorConfigYAML = pkgs.writeText "prometheus-collector.yaml" ''
    global:
      scrape_interval:     60s
      evaluation_interval: 60s
      scrape_timeout:      5s

    rule_files: []

    scrape_configs:
      - job_name: prometheus-collector
        static_configs:
          - targets: ['localhost:${toString collectorPort}']

      - job_name: prometheus-persister
        static_configs:
          - targets: ['localhost:${toString persisterPort}']

      - job_name: consul
        consul_sd_configs:
          - server: 127.0.0.1:8500
        relabel_configs:
          - source_labels: [__meta_consul_tags]
            regex: '.*,prometheus,.*'
            action: keep
          - source_labels: [__meta_consul_node]
            target_label: instance
          - source_labels: [__meta_consul_service]
            target_label: job
          - source_labels: [__meta_consul_service_metadata_metrics_path]
            target_label: __metrics_path__
            regex: (.+)
  '';

  persisterConfigYAML = pkgs.writeText "prometheus-persister.yaml" ''
    global:
      scrape_interval:     15s
      evaluation_interval: 60s
      scrape_timeout:      5s

    rule_files: []

    scrape_configs:
      - job_name: federate
        honor_labels: true
        metrics_path: '/federate'

        static_configs:
          - targets: ['localhost:${toString collectorPort}']

        params:
          'match[]':
            # for the "Node Stats" dashboard
            - node_cpu_seconds_total
            - node_filesystem_free_bytes
            - node_filesystem_size_bytes
            - node_load1
            - node_load5
            - node_memory_MemAvailable_bytes
            - node_memory_MemTotal_bytes
            - node_memory_SwapFree_bytes
            - node_memory_SwapTotal_bytes
            - node_network_receive_bytes_total
            - node_network_transmit_bytes_total
  '';

  instances = {
    prometheus-collector = { port = collectorPort; configYAML = collectorConfigYAML; retention = "1h";  };
    prometheus-persister = { port = persisterPort; configYAML = persisterConfigYAML; retention = "60d"; };
  };

in {

  options.my.services.prometheus.enable = mkEnableOption "prometheus";

  config = mkIf cfg.enable {

    users.groups.prometheus = {};

    users.users.prometheus = {
      description = "Prometheus service user";
      group = "prometheus";
      isSystemUser = true;
      home = "/var/empty";
    };

    # no need to backup ephemeral data that's never more than one hour old
    my.services.borgbackup.excludedPaths = [ "/var/lib/prometheus-collector" ];

    networking.firewall.interfaces.wg-monitoring.allowedTCPPorts = let
      prometheusPorts = map (opts: opts.port) (attrValues instances);
    in prometheusPorts ++ [ serviceDiscoveryPort ];

    systemd.services = let
      prometheusServices = mapAttrs (serviceName: serviceOpts: {
        wantedBy = [ "multi-user.target" ];
        description = "${serviceName} server";

        serviceConfig = {
          ExecStart = "${pkgs.prometheus}/bin/prometheus --config.file=${serviceOpts.configYAML} --storage.tsdb.path=/var/lib/${serviceName} --web.listen-address=:${toString serviceOpts.port} --storage.tsdb.retention=${serviceOpts.retention}";
          ExecReload = "${pkgs.utillinux}/bin/kill -HUP $MAINPID";

          User = "prometheus";
          Group = "prometheus";
          WorkingDirectory = "/var/lib/${serviceName}";
          StateDirectory = serviceName;
        };
      }) instances;
      auxiliaryServices = {
        prometheus-minimum-viable-sd-collect = {
          wantedBy = [ "multi-user.target" ];
          description = "Minimum Viable service discovery for Prometheus";

          serviceConfig = {
            ExecStart = "${serviceDiscoveryPackage}/bin/prometheus-minimum-viable-sd collect /run/prometheus/services.json :${toString serviceDiscoveryPort}";
            Restart = "always";
            RestartSec = "10s";

            # run under same user/group as prometheus-collector, since prometheus-collector needs to read our runtime directory
            User = "prometheus";
            Group = "prometheus";

            # hardening: this process is only supposed to listen on its TCP socket and write to its output file
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
            RuntimeDirectory = "prometheus";
            SystemCallArchitectures = "native";
            SystemCallErrorNumber = "EPERM";
            SystemCallFilter = "@system-service";
          };
        };
      };
    in mkMerge [ prometheusServices auxiliaryServices ];

  };

}
