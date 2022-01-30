# This module is used by all machines with static websites that come from Git repos.
# REPLACES hologram-nginx

{ config, pkgs, lib, ... }:

with lib;

let

  pull-repo-sh = pkgs.writeScript "shove-pull-repo.sh" ''
    #!/bin/sh
    set -euo pipefail
    SOURCE_PROVIDER="$1"
    SOURCE_NAME="$2"
    CHECKOUT_DIR="$3"

    KEY_FILE="${homeDir}/keys/deploy-key-''${SOURCE_NAME/\//-}"
    if [ -f "$KEY_FILE" ]; then
      SOURCE_URL="git@$SOURCE_PROVIDER:$SOURCE_NAME"
      export GIT_SSH_COMMAND="ssh -i $KEY_FILE"
    else
      SOURCE_URL="https://$SOURCE_PROVIDER/$SOURCE_NAME"
    fi

    if [ -d "$CHECKOUT_DIR" ]; then
      git -C "$CHECKOUT_DIR" pull
    else
      git clone "$SOURCE_URL" "$CHECKOUT_DIR"
    fi
  '';

  link-repo-sh = pkgs.writeScript "shove-link-repo.sh" ''
    #!/bin/sh
    set -euo pipefail
    CHECKOUT_DIR="$1"
    TARGET_DIR="$2"
    ln -sTf "''$(readlink -f "$CHECKOUT_DIR")" "$TARGET_DIR"
  '';

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

    buildCommand = mkOption {
      description = "path to alternate build script, invoked with arguments: repository directory, target directory";
      default = toString link-repo-sh;
      type = types.str;
    };

    extraCSPs = mkOption {
      description = "extra Content-Security-Policy directives to apply to this domain";
      default = [];
      type = types.listOf types.str;
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
      actions = mapAttrsToList (domainName: { repositoryProvider, repositoryName, buildCommand, ... }: {
        name = "pull ${repositoryProvider}/${repositoryName} into ${docroot}/${domainName}";
        on = [
          { events = ["shove-startup"]; }
          { events = ["push"]; repos = [repositoryName]; }
        ];
        run = {
          command = [
            "/bin/sh" "-c"
            ''"${pull-repo-sh}" "$1" "$2" "$3" && "${buildCommand}" "$3" "$4"''
            "shove-update-${domainName}"        # this is $0
            repositoryProvider
            repositoryName
            "${homeDir}/checkout/${domainName}" # Git repo directory
            "${docroot}/${domainName}"          # target directory
          ];
        };
      }) cfg.sites;
    };

    users.groups.shove = {};
    users.users.shove = {
      group = "shove";
      isSystemUser = true;
      description = "system user for shove (GitHub webhook handler)";
      home = "/var/empty";
    };

    systemd.services."shove-early" = {
      description = "Pre-start script for shove.service that runs with root perms";
      serviceConfig = {
        Type = "oneshot";
      };

      path = with pkgs; [ coreutils ];
      script = ''
        chmod 0755 ${homeDir}
        install -d -m 0700 -o shove -g shove ${homeDir}/keys
        install -D -m 0600 -o shove -g shove /nix/my/unpacked/deploy-key-* ${homeDir}/keys/
      '';
    };

    systemd.services.shove = {
      description = "GitHub webhook handler for static websites";
      requires = [ "network-online.target" "shove-early.service" ];
      after = [ "network.target" "network-online.target" "shove-early.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ config.environment.etc."shove/shove.yaml".source ];
      path = with pkgs; [ git shove openssh ];

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

      extraConfig = let
        defaultCSPs = ["default-src 'self' 'unsafe-inline';" "img-src 'self' data:;"];
      in ''
        charset utf-8;

        # recommended HTTP headers according to https://securityheaders.io
        add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always; # six months
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Feature-Policy "accelerometer 'none', ambient-light-sensor 'none', autoplay 'none', camera 'none', document-domain 'none', encrypted-media 'none', fullscreen 'none', geolocation 'none', gyroscope 'none', magnetometer 'none', microphone 'none', midi 'none', payment 'none', picture-in-picture 'none', sync-xhr 'none', usb 'none', vibrate 'none', vr 'none'" always;

        # CSP includes unsafe-inline to allow <style> tags in hand-written HTML
        add_header Content-Security-Policy "${concatStringsSep " " (defaultCSPs ++ domainOpts.extraCSPs)}" always;

        # hamper Google surveillance
        add_header Permissions-Policy "interest-cohort=()" always;
      '';
    }) cfg.sites;

    my.services.nginx.fqdnLocations."/shove".proxyPass = "http://127.0.0.1:${toString shoveListenPort}";

  };

}
