# This module provides an Arch Linux mirror.

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.archlinux-mirror;
  enable = cfg.domainName != null;

  homeDir = "/var/lib/archlinux-mirror";
  docroot = "${homeDir}/repo";

  clone-archlinux-mirror = pkgs.writeScriptBin "clone-archlinux-mirror" ''
    #!/usr/bin/env bash
    set -euo pipefail

    exec 9>${homeDir}/lock
    flock -n 9 || exit

    rsync_cmd() {
        local -a cmd=(rsync -rtvlH --safe-links --delete-after "--timeout=600" "--contimeout=60" -p \
            --delay-updates --no-motd "--temp-dir=${homeDir}/tmp" "--bwlimit=4M")
        if stty &>/dev/null; then
            cmd+=(-h -v --progress)
        else
            cmd+=(--quiet)
        fi
        "''${cmd[@]}" "$@"
    }

    # if we are called without a tty (cronjob) only run when there are changes
    if ! tty -s && [[ -f "${docroot}/lastupdate" ]] && diff -b <(curl -Ls "${cfg.upstreamHttpUrl}/lastupdate") "${docroot}/lastupdate" >/dev/null; then
      # keep lastsync file in sync for statistics generated by the Arch Linux website
      rsync_cmd "${cfg.upstreamRsyncUrl}/lastsync" "${docroot}/lastsync"
      exit 0
    fi

    rsync_cmd \
      --exclude='*.links.tar.gz*' \
      --exclude='/other' \
      --exclude='/sources' \
      "${cfg.upstreamRsyncUrl}/" \
      "${docroot}/"
  '';

in {

  options.my.services.archlinux-mirror = {
    domainName = mkOption {
      default = null;
      description = "domain name for the Arch Linux mirror";
      type = types.nullOr types.str;
    };

    upstreamHttpUrl = mkOption {
      description = "HTTP URL of the tier 1 mirror from which this mirror syncs";
      type = types.str;
    };
    upstreamRsyncUrl = mkOption {
      description = "rsync URL of the tier 1 mirror from which this mirror syncs";
      type = types.str;
    };
  };

  config = mkIf enable {

    users.users.archlinux-mirror = {
      description = "archlinux-mirror service user";
      group       = "nogroup";
      home        = homeDir;
      createHome  = true;
    };

    systemd.services.archlinux-mirror-early = {
      description = "Pre-start script for archlinux-mirror.service that runs with root perms";
      serviceConfig = {
        Type = "oneshot";
        RequiresMountsFor = homeDir;
      };

      path = with pkgs; [ coreutils ];
      script = ''
        # nginx needs to be able to look inside the docroot
        chown archlinux-mirror:nogroup ${homeDir}
        chmod 0755 ${homeDir}
        install -d -m 0755 -o archlinux-mirror -g nogroup ${docroot}
        install -d -m 0700 -o archlinux-mirror -g nogroup ${homeDir}/tmp
      '';
    };

    environment.systemPackages = [ clone-archlinux-mirror ];

    systemd.services.archlinux-mirror = {
      description = "sync Arch Linux package mirror";
      requires = [ "network-online.target" "archlinux-mirror-early.service" ];
      after = [ "network.target" "network-online.target" "archlinux-mirror-early.service" ];
      path = with pkgs; [ bash curl diffutils rsync utillinux ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${clone-archlinux-mirror}/bin/clone-archlinux-mirror";

        # security hardening
        User = "archlinux-mirror";
        Group = "nogroup";
        WorkingDirectory = homeDir;
        ReadOnlyPaths = "/";
        ReadWritePaths = homeDir;
        PrivateDevices = "yes";
        PrivateTmp = "yes";
      };
    };

    systemd.timers.archlinux-mirror = {
      description = "sync Arch Linux package mirror every 5 minutes";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "120";
        OnUnitInactiveSec = "300";
      };
    };

    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;
      locations."/".root = docroot;

      extraConfig = ''
        autoindex on;

        # recommended HTTP headers according to https://securityheaders.io
        add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always; # six months
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Feature-Policy "accelerometer 'none', ambient-light-sensor 'none', autoplay 'none', camera 'none', document-domain 'none', encrypted-media 'none', fullscreen 'none', geolocation 'none', gyroscope 'none', magnetometer 'none', microphone 'none', midi 'none', payment 'none', picture-in-picture 'none', sync-xhr 'none', usb 'none', vibrate 'none', vr 'none'" always;
        add_header Content-Security-Policy "default-src 'self';" always;

        # hamper Google surveillance
        add_header Permissions-Policy "interest-cohort=()" always;
      '';
    };

  };

}
