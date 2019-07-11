# This module deploys a static Grafana installation that pulls data from Prometheus.
# REPLACES hologram-monitoring-server (partially)

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.grafana;
  internalListenPort = 28563;

  # TODO 19.03: use config.services.grafana.provision options

  # copy the entire ./grafana-dashboards directory into the /nix/store.
  dashboardsDir = builtins.path { path = ./grafana-dashboards; name = "grafana-dashboards"; };

  dashboardsConfigDir = pkgs.writeTextFile {
    name = "grafana-provisioning-dashboards";
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
          path: ${dashboardsDir}
    '';
  };

  datasourcesConfigDir = pkgs.writeTextFile {
    name = "grafana-provisioning-datasources";
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
    { path = toString datasourcesConfigDir; name = "datasources"; }
    { path = toString dashboardsConfigDir; name = "dashboards"; }
  ];

  ldapConfigFile = pkgs.writeText "grafana-ldap.toml" ''
    [[servers]]
    host = "${config.my.ldap.domainName}"
    port = 636
    use_ssl = true

    bind_dn = "uid=${config.my.ldap.searchUserName},ou=users,${config.my.ldap.suffix}"
    bind_password = """${config.my.ldap.searchUserPassword}"""

    search_filter = "(uid=%s)"
    search_base_dns = ["ou=users,${config.my.ldap.suffix}"]

    [servers.attributes]
    name = "givenName"
    surname = "sn"
    username = "uid"
    member_of = "isMemberOf"
    # email = ""

    [[servers.group_mappings]]
    group_dn = "cn=grafana-admins,ou=groups,${config.my.ldap.suffix}"
    org_role = "Admin"
    grafana_admin = true

    [[servers.group_mappings]]
    group_dn = "*"
    org_role = "Viewer"
  '';

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
      auth.anonymous.enable = false;

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

        AUTH_LDAP_ENABLED = "true";
        AUTH_LDAP_CONFIG_FILE = ldapConfigFile;
        AUTH_LDAP_ALLOW_SIGN_UP = "true"; # allow the LDAP driver to create new users in the Grafana DB
      };
    };

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;

      locations."/".proxyPass = "http://127.0.0.1:${toString internalListenPort}/";

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
