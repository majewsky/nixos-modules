# This module deploys a static Grafana installation that pulls data from Prometheus.
# REPLACES hologram-monitoring-server (partially)

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.grafana;
  internalListenPort = 28563;

  dashboardsDir = pkgs.writeTextFile {
    name = "grafana-dashboards";
    destination = "/dashboards.yaml";
    text = ''
      apiVersion: 1

      providers:
      - name: default
        orgId: 1
        folder: ""
        type: file
        disableDeletion: false
        updateIntervalSeconds: 60 # how often Grafana will scan for changed dashboards
        options:
          path: /x/src/github.com/majewsky/nixos-modules/grafana-dashboards
    '';
    # TODO: the path in /x/src is not readable for the grafana user
  };

  datasourcesDir = pkgs.writeTextFile {
    name = "grafana-datasources";
    destination = "/prometheus.yaml";
    text = ''
      apiVersion: 1
      deleteDatasources:
        - name: Prometheus
          orgId: 1
      datasources:
        - name: Prometheus
          orgId: 1
          type: prometheus
          access: proxy
          url: http://${cfg.prometheusHost}
          editable: false
    '';
  };

  provisioningDir = pkgs.linkFarm "grafana-provisioning" [
    { path = toString datasourcesDir; name = "datasources"; }
    { path = toString dashboardsDir; name = "dashboards"; }
  ];

in {

  options.my.services.grafana = {
    domainName = mkOption {
      default = null;
      description = "domain name for Grafana (must be given to enable the service)";
      type = types.nullOr types.str;
    };
    prometheusHost = mkOption {
      description = "hostname (or IP address) and port of the Prometheus instance used by Grafana as a datasource";
      type = types.str;
    };
    adminPassword = mkOption {
      description = "password for admin user of Grafana";
      type = types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    services.grafana = {
      enable  = true;
      port    = internalListenPort;
      domain  = cfg.domainName;
      rootUrl = "https://${cfg.domainName}/";

      analytics.reporting.enable = false;

      extraOptions = {
        LOG_MODE = "console";
        LOG_LEVEL = "info";

        PATHS_PROVISIONING = provisioningDir;

        SECURITY_ADMIN_USER = "admin";
        SECURITY_ADMIN_PASSWORD = cfg.adminPassword;
        SECURITY_DISABLE_GRAVATAR = "true";
        SECURITY_DATA_SOURCE_PROXY_WHITELIST = cfg.prometheusHost;

        SESSION_PROVIDER = "memory";
        SESSION_COOKIE_SECURE = "true";

        SNAPSHOTS_EXTERNAL_ENABLED = "false";
        ALERTING_ENABLED = "false";
      };
    };

    services.nginx.virtualHosts = setAttrByPath [cfg.domainName] {
      forceSSL = true;
      enableACME = true;

      locations."/".proxyPass = "http://localhost:${toString internalListenPort}/";

      extraConfig = ''
        # recommended HTTP headers according to https://securityheaders.io
        add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always; # six months
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Feature-Policy "accelerometer 'none', ambient-light-sensor 'none', autoplay 'none', camera 'none', document-domain 'none', encrypted-media 'none', fullscreen 'none', geolocation 'none', gyroscope 'none', magnetometer 'none', microphone 'none', midi 'none', payment 'none', picture-in-picture 'none', sync-xhr 'none', usb 'none', vibrate 'none', vr 'none'" always;
        add_header Content-Security-Policy "default-src 'self' 'unsafe-eval' 'unsafe-inline'" always;
      '';
    };

  };

}
