# This module is imported by every system where I have physical access.
# REPLACES hologram-base-accessible

{ config, pkgs, lib }: {

  imports = [ ./base.nix ];

  config = {

    environment.systemPackages = with pkgs; [
      # TODO pwget
      # TODO pwget2
      acpi
      dosfstools # mkfs.vfat
      hdparm
      inotify-tools # inotifywait
      irssi
      iw
      optipng
      p7zip
      smartmontools
      sshfs
      unzip
      whois
      zip
    ];

    ############################################################################
    # systemd: don't block for 90s when a service does not shut down in a timely fashion
    systemd.extraConfig = ''
      DefaultTimeoutStopSec=15s
    '';

    # systemd-journald: volatile storage plus forwarding to tty12
    services.journald = {
      console = 'tty12';
      extraConfig = ''
        MaxLevelConsole=info
        Storage=volatile
        RuntimeMaxUse=100M
      '';
    };

    # Git identity
    majewsky.git = {
      userName = "Stefan Majewsky";
      userEMail = "majewsky@gmx.net";
    };
  };

}
