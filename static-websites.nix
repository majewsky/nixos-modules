# This module is used by all machines with static websites that come from Git repos.
# REPLACES hologram-nginx

{ config, pkgs, lib, ... }:

with lib;

let

  optionsPerWebsite = {
    repositoryProvider = mkOption {
      description = "the hostname where the repository is stored";
      default = "github.com";
      type = types.str;
    };

    repositoryName = mkOption {
      description = "the repository name, usually in the form owner-name/repo-name";
      type = types.str;
    };
  };

  cfg = config.my.services.staticweb;

  # things that could be options if this were to move to a generic location
  homeDir = "/var/lib/shove";
  docroot = "${homeDir}/docroot";
  secretKeyFile = toString /nix/my/unpacked/generated-shove-secret;
  shoveListenPort = 30482;

  shove = (pkgs.callPackage ./pkgs/shove/default.nix {});

in {

  options.my.services.staticweb = {
    sites = mkOption {
      description = "static websites that are served from Git repos";
      example = {
        "doc.example.com" = { repositoryName = "example.com/doc-website"; };
      };
      default = {};
      type = with types; attrsOf (submodule { options = optionsPerWebsite; });
    };
  };

  config = mkIf (cfg.sites != {}) {

    environment.systemPackages = with pkgs; [
      shove
      git # used by /etc/shove/pull-static-website.sh
    ];

    # note that JSON is a subset of YAML
    environment.etc."shove/shove.yaml".text = builtins.toJSON {
      actions = mapAttrsToList (domainName: { repositoryProvider, repositoryName, ... }: {
        name = "pull ${repositoryProvider}/${repositoryName} into ${docroot}/${domainName}";
        on = [
          { events = ["shove-startup"]; }
          { events = ["push"]; repos = [repositoryName]; }
        ];
        run = {
          command = [ "/etc/shove/pull-static-website.sh" "https://${repositoryProvider}/${repositoryName}" "${docroot}/${domainName}" ];
        };
      }) cfg.sites;
    };

    # TODO atomic upgrades
    environment.etc."shove/pull-static-website.sh" = {
      mode = "0555";
      text = ''
        #!/bin/sh
        set -euo pipefail
        SOURCE_URL="$1"
        TARGET_DIR="$2"
        if [ -d "$TARGET_DIR" ]; then
          git -C "$TARGET_DIR" pull
        else
          git clone "$SOURCE_URL" "$TARGET_DIR"
        fi
      '';
    };

    users.groups.shove = {};
    users.users.shove = {
      group = "shove";
      isSystemUser = true;
      description = "system user for shove (GitHub webhook handler)";
      home = homeDir;
      createHome = true;
    };

    systemd.services."shove-early" = {
      description = "Pre-start script for shove.service that runs with root perms";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/chmod 0755 ${homeDir}";
      };
    };

    systemd.services.shove = {
      description = "GitHub webhook handler for static websites";
      requires = [ "network-online.target" "shove-early.service" ];
      after = [ "network.target" "network-online.target" "shove-early.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ config.environment.etc."shove/shove.yaml".text ];
      path = with pkgs; [ git shove ];

      environment = {
        SHOVE_PORT = toString shoveListenPort;
        SHOVE_CONFIG = "/etc/shove/shove.yaml";
      };

      serviceConfig = {
        ExecStart = "${shove}/bin/shove";
        EnvironmentFile = "${secretKeyFile}";

        # security hardening
        User = "shove";
        Group = "shove";
        WorkingDirectory = homeDir;
        ReadOnlyPaths = "/";
        ReadWritePaths = homeDir;
        PrivateDevices = "yes";
        PrivateTmp = "yes";
      };
    };

    services.nginx.virtualHosts = mapAttrs (domainName: domainOpts: {
      forceSSL = true;
      enableACME = true;

      locations."/.git/".extraConfig = ''
        deny all;
        return 404;
      '';

      locations."/".root = "${docroot}/${domainName}";
    }) cfg.sites;

    my.services.nginx.fqdnLocations."/shove".proxyPass = "http://127.0.0.1:${toString shoveListenPort}";

  };

}
