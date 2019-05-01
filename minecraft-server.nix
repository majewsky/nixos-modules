{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.minecraft;

  minecraftShell = pkgs.writeScriptBin "minecraft-shell" ''
    #!${pkgs.bashInteractive}/bin/bash -i
    ${builtins.readFile ./pkgs/minecraft-shell.sh}
  '';

in {

  options.my.services.minecraft = {
    enable = mkEnableOption "Minecraft server";
  };

  config = mkIf cfg.enable {

    # TODO: borgbackup instead of backup via Git
    # TODO FIXME: fix `stop` command

    users.groups.minecraft = {};
    users.users.minecraft = {
      isNormalUser = true;
      group = "minecraft";
      home = "/var/lib/minecraft";
      createHome = true;
      shell = "${minecraftShell}/bin/minecraft-shell";
      openssh.authorizedKeys.keyFiles = [ /nix/my/unpacked/ssh-keys-minecraft ];
    };

    networking.firewall.allowedTCPPorts = [ 25565 ];

    # need lingering session to keep minecraft@.service running
    systemd.services.minecraft-early = {
      description = "Minecraft server";
      after = [ "systemd-logind.service" ];
      wants = [ "systemd-logind.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";
      script = "loginctl enable-linger minecraft";
    };

    systemd.user.services."minecraft@" = {
      description = "Minecraft server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        OOMScoreAdjust = "1000";
      };

      scriptArgs = ''"%i"'';
      script = ''
        set -euo pipefail
        cd "$HOME/servers/$1/Server\ Files"
        source ServerStart.sh
      '';

    };

  };

}
