# This module is used on every system where I have physical access (and where I
# therefore want a broader tool selection), regardless of whether I have a
# screen or not.
# REPLACES hologram-base-accessible

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.workstation;

  pwget = pkgs.callPackage ./pkgs/pwget/default.nix {};
  pwget2 = pkgs.callPackage ./pkgs/pwget2/default.nix {};

in {

  options.my.workstation = let
    mkBoolOpt = description: mkOption { default = false; example = true; inherit description; type = types.bool; };
  in {
    enabled = mkBoolOpt "Whether to enable the configuration parts for systems with physical access.";
    headless = mkBoolOpt "Whether to exclude configuration parts that relate to GUI access.";
  };

  config = mkIf cfg.enabled {

    environment.systemPackages = with pkgs; [
      dosfstools # mkfs.vfat (e.g. for UEFI system partition)
      gnupg
      hdparm
      inotify-tools # inotifywait
      irssi
      p7zip
      pwget
      pwget2
      qt5.qttools # qdbus
      smartmontools
      sshfs
      pythonPackages.tabulate
      unzip
      whois
      yt-dlp
      zip

      # TODO rest
    ];

    programs.gnupg = {
      agent.enable = true;
      agent.pinentryFlavor = if cfg.headless then "curses" else "qt";
    };

    # systemd: don't block for 90s when a service does not shut down in a timely fashion
    systemd.extraConfig = ''
      DefaultTimeoutStopSec=15s
    '';

    # systemd-journald: volatile storage plus forwarding to tty12
    services.journald = {
      console = "tty12";
      extraConfig = ''
        MaxLevelConsole=info
        Storage=volatile
        RuntimeMaxUse=100M
      '';
    };

    # setup console and keyboard layout
    services.xserver.layout     = "eu";
    services.xserver.xkbVariant = "";
    services.xserver.xkbOptions = "caps:escape";
    console.useXkbConfig = true;
    console.font = "Lat2-Terminus16";

  };
}
