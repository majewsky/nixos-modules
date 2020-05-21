# This module is imported by every system where I have physical access.
# REPLACES hologram-base-accessible
# REPLACES hologram-base-gui-minimal
# TODO hologram-base-gui
# TODO hologram-multimedia-base
# TODO hologram-devtools
# TODO hologram-devtools-minimal
# TODO hologram-dtp
# TODO hologram-games
# TODO hologram-kde-desktop-minimal
# TODO hologram-kde-desktop
# TODO hologram-sway-desktop

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.workstation;

  essentialPackages = with pkgs; [
    # command-line utilities
    acpi
    dosfstools # mkfs.vfat
    hdparm
    inotify-tools # inotifywait
    irssi
    iw
    p7zip
    # TODO pwget
    # TODO pwget2
    smartmontools
    sshfs
    unzip
    whois
    zip

    # X11 utilities
    xorg.xev
    xorg.xlsclients
    xorg.xmodmap
    xorg.xprop
    xorg.xrandr
    xsel

    # GUI programs
    firefox
    gnuplot # TODO gvim mupdf screen-message

    # image viewing/manipulation
    graphviz
    imagemagick
    inkscape
    optipng
    sxiv
    svgcleaner

    # audio
    paprefs
    pavucontrol

    # programming
    gitAndTools.gitFull
    gitAndTools.qgit

    # fonts
    cantarell-fonts
    dejavu_fonts
    freefont_ttf
    iosevka
    liberation_ttf
    libertine
    montserrat
    noto-fonts
    noto-fonts-emoji
    noto-fonts-extra
    raleway
    roboto
    source-code-pro
    source-sans-pro
    source-serif-pro
    # TODO titillium
    ttf_bitstream_vera
    ubuntu_font_family
  ];

  additionalPackages = with pkgs; [
    # multimedia
    audacity
    mumble
    vlc

    # productivity
    gnucash
  ];

in {

  options.my.workstation = let
    mkBoolOpt = description: mkOption { default = false; example = true; inherit description; type = types.bool; };
  in {
    enabled = mkBoolOpt "Whether to enable the configuration parts for systems with physical access.";
    minimal = mkBoolOpt "Whether to apply a limited application selection.";
  };

  config = mkIf cfg.enabled {

    services.xserver.enable = true;
    environment.systemPackages = essentialPackages ++ (optionals (!cfg.minimal) additionalPackages);

    # select display manager
    services.xserver.displayManager = {
      defaultSession = if cfg.minimal then "plasma5" else "sway";
      sddm = {
        enable = true;
        # autoLogin.enable = true;
        # autoLogin.user = "stefan";
      };
    };

    # use Sway desktop
    programs.sway = mkIf (!cfg.minimal) {
      enable = true;
      extraPackages = with pkgs; [
        dmenu
        grim
        i3status-rust
        mako
        qt5.qtwayland
        swayidle
        swaylock
        xwayland
      ];
      extraSessionCommands = ''
        export MOZ_ENABLE_WAYLAND=1
        export SDL_VIDEODRIVER=wayland
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      '';
    };

    # use Plasma desktop (as fallback when something is not working in Wayland)
    services.xserver.desktopManager.plasma5.enable = true;

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

    # setup audio stack
    hardware.pulseaudio = {
      enable = true;
      zeroconf.discovery.enable = true;
    };
    services.avahi.enable = true;

    # setup keyboard layout
    services.xserver.layout     = "us";
    services.xserver.xkbVariant = "altgr-intl";
    services.xserver.xkbOptions = "caps:escape";

    # apply keyboard layout settings to Sway
    environment.sessionVariables = let cfg = config.services.xserver; in {
      XKB_DEFAULT_LAYOUT  = cfg.layout;
      XKB_DEFAULT_VARIANT = cfg.xkbVariant;
      XKB_DEFAULT_OPTIONS = cfg.xkbOptions;
    };

    # TODO port nightwatch from hologram-base-gui?

  };

}
