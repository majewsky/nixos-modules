# This module deploys Taiga, a project management software.
{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.taiga;

  internalBackendListenPort = 17695;

  taiga-backend-package = pkgs.callPackage ./pkgs/taiga-backend/default.nix {};
  taiga-frontend-package = pkgs.callPackage ./pkgs/taiga-frontend/default.nix {};

in {

  options.my.services.taiga = {
    domainName = mkOption {
      default = null;
      description = "domain name for Taiga (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    containers.taiga = {
      autoStart = true;
      forwardPorts = [{
        containerPort = internalBackendListenPort;
        hostPort = internalBackendListenPort;
      }];
      privateNetwork = true;
      hostAddress = "192.168.100.1";
      localAddress = "192.168.100.2";

      config = {config, pkgs, lib, ... }: with lib; {

        environment.systemPackages = with pkgs; [
          gettext       # taiga-back needs msgfmt(1)
          postgresql_11 # for psql(1)
          # taiga-backend-package # NOT, see below
        ];

        users.groups.taiga.gid = 1000;
        users.users.taiga = {
          uid = 1000;
          group = "taiga";
          home = "/";
          shell = pkgs.bashInteractive;
        };

        services.postgresql = {
          enable = true;
          dataDir = "/var/lib/postgresql";
          package = pkgs.postgresql_11;
          initialScript = pkgs.writeText "taiga-postgres-init.sql" ''
            CREATE USER taiga;
            CREATE DATABASE taiga OWNER taiga ENCODING 'utf-8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0;
          '';
        };

        # taiga-back *insists* on being able to write into its source directory,
        # so wrap ${taiga-backend-package.out} into a writable overlayfs
        #
        # This does not use the fileSystems.${path} option because it does
        # not create the upperdir and workdir beforehand.
        #
        # This does not use the systemd.mounts option because systemd does not
        # restart the mount correctly when ${taiga-backend-package} changes.
        # <https://github.com/systemd/systemd/issues/7007>
        systemd.services.taiga-back-overlay = {
          description = "setup taiga-back overlayfs";
          unitConfig.RequiresMountsFor = "/";
          restartTriggers = [ taiga-backend-package ];

          path = with pkgs; [ coreutils findutils utillinux ];
          script = let
            options = concatStringsSep "," [
              "lowerdir=${taiga-backend-package}"
              "upperdir=/taigaback/upperdir"
              "workdir=/taigaback/workdir"
            ];
          in ''
            set -euo pipefail
            mkdir -p /taigaback/{overlayfs,upperdir,workdir}
            while [ -d /taigaback/overlayfs/bin ]; do
              umount /taigaback/overlayfs || exit $?
            done
            mount -t overlay overlay -o ${options} /taigaback/overlayfs
            # allow taiga-manage etc. to write into the Taiga source tree
            find /taigaback/overlayfs/taiga/ -type d -exec chown taiga:taiga {} +
            find /taigaback/overlayfs/taiga/ -type d -exec chmod u+w {} +
            # need to remain running, otherwise ExecStop= is executed immediately
            exec tail -f /dev/null
          '';
          preStop = ''
            while [ -d /taigaback/overlayfs/bin ]; do
              ${pkgs.utillinux}/bin/umount /taigaback/overlayfs || exit $?
            done
            exit 0
          '';
        };
        # use bin/ from that overlayfs rather than ${taiga-backend-package.out},
        # so that `taiga-manage` can actually write into the places it wants to
        # write into
        environment.extraInit = ''
          export PATH="/taigaback/overlayfs/bin:$PATH"
        '';

        environment.etc."taiga/settings/local.py".text = ''
          from .common import *

          MEDIA_URL = "https://${cfg.domainName}/media/"
          STATIC_URL = "https://${cfg.domainName}/static/"
          SITES["front"]["scheme"] = "https"
          SITES["front"]["domain"] = "${cfg.domainName}"

          DEBUG = False
          PUBLIC_REGISTER_ENABLED = False

          DEFAULT_FROM_EMAIL = "noreply@${cfg.domainName}"
          SERVER_EMAIL = DEFAULT_FROM_EMAIL
        '';

        systemd.services.taiga-back = {
          description = "Taiga backend";
          requires = [ "taiga-back-overlay.service" ];
          after    = [ "taiga-back-overlay.service" "network.target" ];
          wantedBy = [ "default.target" ];
          restartTriggers = [
            taiga-backend-package
            config.environment.etc."taiga/settings/local.py".source
          ];

          serviceConfig = {
            User = "taiga";
            Group = "taiga";
            WorkingDirectory = "/taigaback/overlayfs/taiga";
            # the following options as recommended by
            # <https://taigaio.github.io/taiga-doc/dist/setup-production.html#systemd-and-gunicorn>
            Environment = "PYTHONUNBUFFERED=true";
            Restart = "always";
            RestartSec = "3";
          };
          script = ''
            /taigaback/overlayfs/bin/taiga-manage migrate --noinput
            /taigaback/overlayfs/venv/bin/gunicorn --workers 4 --timeout 60 -b 0.0.0.0:${toString internalBackendListenPort} taiga.wsgi
          '';
        };

        # allow host system to access taiga-back service
        networking.firewall.allowedTCPPorts = [ internalBackendListenPort ];

      };
    };

    environment.etc."taiga-frontend/conf.json".text = builtins.toJSON {
      api = "https://taiga.bethselamin.de/api/v1/";
      eventsUrl = null;
      eventsMaxMissedHeartbeats = 5;
      eventsHeartbeatIntervalTime = 60000;
      eventsReconnectTryInterval = 10000;
      debug = false;
      debugInfo = false;
      defaultLanguage = "en";
      themes = ["taiga"];
      defaultTheme = "taiga";
      publicRegisterEnabled = false;
      feedbackEnabled = false;
      supportUrl = "https://tree.taiga.io/support/";
      privacyPolicyUrl = null;
      termsOfServiceUrl = null;
      GDPRUrl = null;
      maxUploadFileSize = null;
      contribPlugins = [];
      tribeHost = null;
      importers = [];
      gravatar = true;
      rtlLanguages = ["fa"];
    };

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;

      # the following options as recommended by
      # <https://taigaio.github.io/taiga-doc/dist/setup-production.html#nginx>
      extraConfig = ''
        large_client_header_buffers 4 32k;
        client_max_body_size 50M;
        charset utf-8;
      '';

      locations = let
        proxyToBackend = {
          proxyPass = "http://192.168.100.1:${toString internalBackendListenPort}$request_uri";
          extraConfig = ''
            proxy_redirect off;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Scheme $scheme;
          '';
        };
      in {
        "/api" = proxyToBackend;
        "/admin" = proxyToBackend;
        "/static".root = "${taiga-backend-package}/taiga/";
        "/media".root = "/var/lib/containers/taiga/taigaback/upperdir/taiga/";
        "/" = {
          root = "${taiga-frontend-package}/dist/";
          tryFiles = "$uri $uri/ /index.html";
        };
        "/conf.json" = {
          root = "/etc/taiga-frontend/";
        };
      };
    };

  };

}
