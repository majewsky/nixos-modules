# This module deploys a static Grafana installation that pulls data from Prometheus.
# REPLACES hologram-monitoring-server (partially)

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.grafana;
  internalListenPort = 28563;

  # copy the entire ./grafana-dashboards directory into the /nix/store.
  dashboardsDir = builtins.path { path = ./grafana-dashboards; name = "grafana-dashboards"; };

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
  };

  config = mkIf (cfg.domainName != null) {

    services.grafana = {
      enable  = true;

      settings = {
        alerting.enabled = false;
        analytics.reporting_enabled = false;
        "auth.anonymous".enabled = false;
        "auth.ldap" = {
          enabled = true;
          config_file = "${ldapConfigFile}";
          allow_sign_up = true; # allow the LDAP driver to create new users in the Grafana DB
        };
        log = {
          mode = "console";
          level = "info";
        };
        security = {
          cookie_secure = true;
          data_source_proxy_whitelist = cfg.prometheusHost;
          disable_gravatar = true;
          disable_initial_admin_creation = true; # rely only on LDAP for admin users
          security_key = "$__file{/var/lib/grafana/secret-key}"; # generated on first start, see `preStart` below
          strict_transport_security = true;
        };
        server = {
          domain    = cfg.domainName;
          http_port = internalListenPort;
          root_url  = "https://${cfg.domainName}/";
        };
        snapshots.external_enabled = false;
        unified_alerting.enabled = false;
      };

      provision.datasources.settings = {
        apiVersion = 1;
        deleteDatasources = [{
          name = "Prometheus";
          orgId = 1;
        }];
        datasources = [{
          name = "Prometheus";
          orgId = 1;
          type = "prometheus";
          access = "proxy";
          url = "http://${cfg.prometheusHost}";
          editable = false;
        }];
      };

      provision.dashboards.settings = {
        apiVersion = 1;
        providers = [{
          name = "default";
          orgID = 1;
          disableDeletion = true;
          # This update is practically disabled because it's not useful here.
          # The dashboards are in the /nix/store, so changing them requires a
          # nixos-rebuild which restarts Grafana anyway.
          updateIntervalSeconds = 86400;
          options.path = dashboardsDir;
        }];
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

        # hamper Google surveillance
        add_header Permissions-Policy "interest-cohort=()" always;
      '';
    };

    systemd.services.grafana = {
      path = [ pkgs.pwgen ];
      preStart = ''
        test -f /var/lib/grafana/secret-key || pwgen 30 1 > /var/lib/grafana/secret-key
      '';
    };

  };

}
