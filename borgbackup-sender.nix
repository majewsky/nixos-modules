{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.my.services.borgbackup;

  script2matrix = pkgs.callPackage ./pkgs/script2matrix/default.nix {};

in {

  options.my.services.borgbackup = {
    targetHost = mkOption {
      description = "hostname or IP of backup receiver";
      default = null;
      type = types.nullOr types.str;
    };
    excludedPaths = mkOption {
      description = "List of paths that will be excluded from the backup.";
      default = [];
      type = types.listOf types.str;
    };
  };

  config = mkIf (cfg.targetHost != null) {
    # default set of excluded paths; other modules can add to this
    my.services.borgbackup.excludedPaths = [
      "/x"
      "/nix"
      "/boot"
      "/var/log/journal"
      "/root/.cache"
    ];

    systemd.services.borgbackup-root = {
      description = "Borg backup for root filesystem";
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
      startAt = "02:00:00"; # before nix-gc.service (at 03:15) and nixos-upgrade.service (at 04:40)

      path = [ pkgs.borgbackup pkgs.openssh pkgs.coreutils script2matrix ];
      script = ''
        exec script2matrix borg create -s --one-file-system --exclude-caches \
          ${concatMapStrings (path: "--exclude ${path} ") cfg.excludedPaths} \
          --compression auto,lzma \
          --rsh "ssh -i /nix/my/unpacked/borgbackup-ssh-key" \
          --upload-ratelimit 10240 \
          "borgrecv@${cfg.targetHost}:/var/lib/borgrecv/repo/${config.networking.hostName}::{utcnow:%Y-%m-%dT%H:%M:%SZ}" /
      '';
      environment = let cfgMatrix = config.my.services.monitoring.matrix; in {
        BORG_PASSCOMMAND = "cat /nix/my/unpacked/generated-borgbackup-key";
        MATRIX_USER = cfgMatrix.userName;
        MATRIX_TARGET = cfgMatrix.target;
      };
      serviceConfig.EnvironmentFile = toString /nix/my/unpacked/generated-matrix-password;

      serviceConfig.Type = "oneshot";

      # despite the hardening below, we need to be able to write to our home
      # directory, i.e. /root/, to access /root/.ssh/known_hosts (writing is not
      # required here) and /root/.cache/borg/ (this one requires write access)
      serviceConfig.ProtectHome = mkForce "no";
    };

    my.hardening.borgbackup-root = {
      allowInternetAccess = true; # to reach backup location
    };

  };

}
