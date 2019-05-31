{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.my.services.borgbackup;

in {

  options.my.services.borgbackup = {
    targetHost = mkOption {
      description = "hostname or IP of backup receiver";
      default = null;
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.targetHost != null) {
    systemd.services.borgbackup-root = {
      description = "Borg backup for root filesystem";
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
      startAt = "02:00:00"; # before nixos-upgrade.service (at 03:15) and nix-gc.service (at 04:40)

      path = [ pkgs.borgbackup pkgs.openssh pkgs.coreutils ];
      script = ''
        borg create -s --one-file-system \
          --exclude /x --exclude /nix --exclude /var/log/journal --exclude-caches \
          --compression auto,lzma \
          --rsh "ssh -i /nix/my/unpacked/borgbackup-ssh-key" \
          --remote-ratelimit 1024 \
          "borgrecv@${cfg.targetHost}:/var/lib/borgrecv/repo/${config.networking.hostName}::{utcnow:%Y-%m-%dT%H:%M:%SZ}" /
      '';
      environment = {
        BORG_PASSCOMMAND = "cat /nix/my/unpacked/generated-borgbackup-key";
      };

      serviceConfig = {
        Type = "oneshot";
      };
    };

  };

}
