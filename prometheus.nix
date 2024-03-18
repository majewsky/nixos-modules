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

  collectorRulesYAML = pkgs.writeText "prometheus-collector-rules.yaml" ''
    groups:
      - name: collector
        rules:
          - record: node_power_supply_charge_watthours
            expr: node_power_supply_charge_ampere * node_power_supply_voltage_volt
  '';

  collectorConfigYAML = pkgs.writeText "prometheus-collector.yaml" ''
    global:
      scrape_interval:     60s
      evaluation_interval: 60s
      scrape_timeout:      5s

    rule_files:
      - ${collectorRulesYAML}

    scrape_configs:
      - job_name: prometheus-collector
        static_configs:
          - targets: ['localhost:${toString collectorPort}']

      - job_name: prometheus-persister
        static_configs:
          - targets: ['localhost:${toString persisterPort}']

      - job_name: service-discovery
        file_sd_configs:
          - files: ['/run/prometheus/services.json']
  '';

  persisterRulesYAML = pkgs.writeText "prometheus-persister-rules.yaml" ''
    groups:
      - name: collector
        rules:
            # This rule tries very hard to continue existing even if the node is down for a bit.
            # I collect this to measure uptime percentage.
          - record: node_up
            expr: (node_load1*0+1) or (min_over_time(node_load1[14d])*0+0)
  '';

  persisterConfigYAML = pkgs.writeText "prometheus-persister.yaml" ''
    global:
      scrape_interval:     15s
      evaluation_interval: 60s
      scrape_timeout:      5s

    rule_files:
      - ${persisterRulesYAML}

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
            # other things that interest me
            - node_hwmon_temp_celsius
            - node_power_supply_charge_ampere
            - node_power_supply_charge_watthours
  '';

  instances = {
    prometheus-collector = { port = collectorPort; configYAML = collectorConfigYAML; retention = "1h";  };
    prometheus-persister = { port = persisterPort; configYAML = persisterConfigYAML; retention = "365d"; };
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
            RuntimeDirectory = "prometheus";
            RuntimeDirectoryPreserve = "restart";
          };
        };
      };
    in mkMerge [ prometheusServices auxiliaryServices ];

    my.hardening = let
      prometheusHardening = mapAttrs (serviceName: serviceOpts: {
        allowInternetAccess = true; # to bind HTTP
        allowWriteAccessTo = [ "/var/lib/${serviceName}" ];
      }) instances;
      auxiliaryHardening = {
        prometheus-minimum-viable-sd-collect = {
          allowInternetAccess = true; # to bind TCP
        };
      };
    in mkMerge [ prometheusHardening auxiliaryHardening ];

  };

}
