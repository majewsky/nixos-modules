# This module is enabled on every system where I have physical access.
# REPLACES hologram-base-accessible
# REPLACES hologram-base-gui-minimal
# TODO hologram-base-gui
# TODO hologram-multimedia-base
# TODO hologram-devtools
# TODO hologram-devtools-minimal
# TODO hologram-dtp
# TODO hologram-games
# TODO hologram-sway-desktop

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.workstation;

  pwget = pkgs.callPackage ./pkgs/pwget/default.nix {};
  pwget2 = pkgs.callPackage ./pkgs/pwget2/default.nix {};

  essentialPackages = with pkgs; [
    # command-line utilities
    acpi
    dosfstools # mkfs.vfat
    hdparm
    inotify-tools # inotifywait
    irssi
    iw
    p7zip
    pwget
    pwget2
    qt5.qttools
    smartmontools
    sshfs
    pythonPackages.tabulate
    unzip
    whois
    zip

    # X11 utilities
    xorg.xev
    xorg.xlsclients
    xorg.xmodmap
    xorg.xprop
    xorg.xrandr

    # Wayland utilities
    alacritty
    bemenu
    wl-clipboard

    # TODO rest

    # GUI programs
    firefox
    gnuplot # TODO mupdf screen-message

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

    fonts.fonts = with pkgs; [
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
    fonts.fontconfig.defaultFonts = {
      serif = [ "Source Serif Pro" ];
      sansSerif = [ "Source Sans Pro" ];
      monospace = [ "Iosevka" ];
    };

    services.xserver.enable = true;
    environment.systemPackages = essentialPackages ++ (optionals (!cfg.minimal) additionalPackages);

    # select display manager
    services.xserver.displayManager = {
      defaultSession = "sway";
      autoLogin = {
        # autologin must be disabled for SDDM 0.19, see <https://github.com/sddm/sddm/pull/1496>
        enable = (lib.versions.majorMinor pkgs.sddm.version) != "0.19";
        user = "stefan";
      };
      sddm = {
        enable = true;
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

    # apply keyboard layout settings to Sway
    environment.sessionVariables = let cfg = config.services.xserver; in {
      XKB_DEFAULT_LAYOUT  = cfg.layout;
      XKB_DEFAULT_VARIANT = cfg.xkbVariant;
      XKB_DEFAULT_OPTIONS = cfg.xkbOptions;
    };

    # TODO port nightwatch from hologram-base-gui?

  };

}
