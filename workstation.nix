# This module is imported by every system where I have physical access.
# REPLACES hologram-base-accessible

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.workstation;

  essentialPackages = with pkgs; [
    # command-line utilities
    # TODO pwget
    # TODO pwget2
    acpi
    dosfstools # mkfs.vfat
    hdparm
    inotify-tools # inotifywait
    irssi
    iw
    p7zip
    smartmontools
    sshfs
    unzip
    whois
    zip

    # multimedia
    optipng
    svgcleaner
  ];

  additionalPackages = with pkgs; [
  ];

in {

  options.my.workstation = let
    mkBoolOpt = description: mkOption { default = false; example = true; inherit description; type = types.bool; };
  in {
    enabled = mkBoolOpt "Whether to enable the configuration parts for systems with physical access.";
    minimal = mkBoolOpt "Whether to apply a limited application selection.";
  };

  config = {

    environment.systemPackages = essentialPackages ++ (optionals cfg.minimal additionalPackages);

    ############################################################################
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

  };

}
