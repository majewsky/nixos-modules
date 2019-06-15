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

    networking.firewall.interfaces.wg-monitoring.allowedTCPPorts = map (opts: opts.port) (attrValues instances);

    systemd.services = mapAttrs (serviceName: serviceOpts: {
      wantedBy = [ "multi-user.target" ];
      description = "${serviceName} server";

      serviceConfig = {
        ExecStart = "${pkgs.prometheus_2}/bin/prometheus --config.file=${serviceOpts.configYAML} --storage.tsdb.path=/var/lib/${serviceName} --web.listen-address=:${toString serviceOpts.port} --storage.tsdb.retention=${serviceOpts.retention}";
        ExecReload = "${pkgs.utillinux}/bin/kill -HUP $MAINPID";

        User = "prometheus";
        Group = "prometheus";
        WorkingDirectory = "/var/lib/${serviceName}";
        StateDirectory = serviceName;
      };
    }) instances;

  };

}
