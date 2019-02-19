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

    deployKey = mkOption {
      description = "a private SSH key that is used to clone this private repository";
      default = null;
      type = types.nullOr types.str;
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
          command = [ "/etc/shove/pull-static-website.sh" repositoryProvider repositoryName "${docroot}/${domainName}" ];
        };
      }) cfg.sites;
    };

    # TODO atomic upgrades
    environment.etc."shove/pull-static-website.sh" = {
      mode = "0555";
      text = ''
        #!/bin/sh
        set -euo pipefail
        SOURCE_PROVIDER="$1"
        SOURCE_NAME="$2"
        TARGET_DIR="$3"

        KEY_FILE="/nix/my/unpacked/deploy-key-''${SOURCE_NAME/\//-}"
        if [ -f "$KEY_FILE" ]; then
          SOURCE_URL="git@$SOURCE_PROVIDER:$SOURCE_NAME"
          export GIT_SSH_COMMAND="ssh -I $KEY_FILE"
        else
          SOURCE_URL="https://$SOURCE_PROVIDER/$SOURCE_NAME"
        fi

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
      restartTriggers = [ config.environment.etc."shove/shove.yaml".source ];
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

      # for TLDs like example.com, support the alias www.example.com
      serverAliases = if (builtins.length (splitString "." domainName)) == 2 then [ "www.${domainName}" ] else [];

      extraConfig = ''
        # recommended HTTP headers according to https://securityheaders.io
        add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always; # six months
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Feature-Policy "accelerometer 'none', ambient-light-sensor 'none', autoplay 'none', camera 'none', document-domain 'none', encrypted-media 'none', fullscreen 'none', geolocation 'none', gyroscope 'none', magnetometer 'none', microphone 'none', midi 'none', payment 'none', picture-in-picture 'none', sync-xhr 'none', usb 'none', vibrate 'none', vr 'none'" always;

        # CSP includes unsafe-inline to allow <style> tags in hand-written HTML
        add_header Content-Security-Policy "default-src 'self' 'unsafe-inline'; img-src 'self' data:;" always;
      '';
    }) cfg.sites;

    my.services.nginx.fqdnLocations."/shove".proxyPass = "http://127.0.0.1:${toString shoveListenPort}";

  };

}
