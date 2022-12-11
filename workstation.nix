# This module is used on every system where I have physical access and a screen.
# REPLACES hologram-base-gui-minimal
# REPLACES hologram-base-gui
# REPLACES hologram-bluetooth-audio
# REPLACES hologram-dev-tools
# REPLACES hologram-dtp
# REPLACES hologram-games
# REPLACES hologram-sway-desktop

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.workstation;

in {

  # NOTE: `options.my.workstation` is defined in workstation-headless.nix

  config = mkIf (cfg.enabled && !cfg.headless) {

    fonts.fonts = with pkgs; [
      cantarell-fonts
      dejavu_fonts
      freefont_ttf
      ipafont
      iosevka
      liberation_ttf
      libertine
      montserrat
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
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

    environment.systemPackages = with pkgs; [
      # command-line utilities
      acpi
      bluez # bluetoothctl
      iw
      lm_sensors # sensors

      # X11 utilities (sometimes needed for debugging Xwayland)
      xorg.xev
      xorg.xlsclients
      xorg.xmodmap
      xorg.xprop
      xorg.xrandr

      # productivity
      firefox
      gnucash
      gnuplot
      libreoffice-still
      mupdf
      screen-message
      texlive.combined.scheme-full

      # image viewing/manipulation
      graphviz
      imagemagick
      inkscape
      optipng
      sxiv
      svgcleaner

      # audio/multimedia
      audacity
      mpc_cli
      mpd
      mpv
      mumble
      ncmpcpp
      obs-studio
      obs-studio-plugins.wlrobs
      pamixer
      pavucontrol
      playerctl
      vlc

      # programming
      cargo
      cargo-watch
      clippy
      gitAndTools.gitFull
      gitAndTools.qgit
      postgresql # for test runs using a Postgres instance in tmpfs (see below, Ctrl-F "pathsToLink")
      rustc
      rustfmt

      # theming
      breeze-icons
      breeze-qt5 # includes breeze cursors
      gnome3.adwaita-icon-theme
      hicolor-icon-theme

      # selected KDE applications
      filelight
      kcharselect
      kcolorchooser
      kid3
      kolourpaint

      # games
      discord
      jre8 # for Minecraft (modpacks for older versions don't work with newer JREs)
      polymc

      # TODO rest
    ];

    # make postgres binaries work outside of postgresql.service (for test runs using Postgres)
    environment.pathsToLink = [ "/share/postgresql" ];

    # enable audio
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # enable Bluetooth for headset audio
    hardware.bluetooth.enable = true;

    # configuration for mpv
    nixpkgs.overlays = [
      (self: super: {
        # in the mpv wrapper, we can select scripts to add to the commandline
        mpv = super.mpv-with-scripts.override {
          scripts = [ self.mpvScripts.mpris ];
        };
        # in the mpv package itself, we can add config to its etc
        mpv-unwrapped = super.mpv-unwrapped.overrideAttrs (attrs: {
          postInstall = attrs.postInstall + ''
            # start with an empty /etc/mpv/mpv.conf
            echo -n "" > mpv.conf
            # never display album covers
            echo 'no-audio-display' >> mpv.conf
            # always start fullscreen by default
            echo 'fs' >> mpv.conf
            # enumerate unfinished videos by examining the watch-later files
            echo 'write-filename-in-watch-later-config' >> mpv.conf
            # install into a place where mpv can find it
            install -D -m 0644 mpv.conf "$out/etc/mpv/mpv.conf"
          '';
        });
      })
    ];
    environment.etc."mpv/mpv.conf".text = ''
      # never display album covers
      no-audio-display
      # always start fullscreen by default
      fs
      # enumerate unfinished videos by examining the watch-later files
      write-filename-in-watch-later-config
    '';

    # select display manager
    services.xserver.enable = true; # required for SDDM greeter
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
    programs.sway = {
      enable = true;
      extraPackages = with pkgs; [
        alacritty
        bemenu
        grim
        i3status-rust
        mako
        qt5.qtwayland
        slurp
        swayidle
        swaylock
        wev
        wl-clipboard
        wtype
      ];
      extraSessionCommands = let cfgX = config.services.xserver; in ''
        export MOZ_ENABLE_WAYLAND=1
        export SDL_VIDEODRIVER=wayland
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        export XKB_DEFAULT_LAYOUT="${cfgX.layout}"
        export XKB_DEFAULT_VARIANT="${cfgX.xkbVariant}"
        export XKB_DEFAULT_OPTIONS="${cfgX.xkbOptions}"
      '';
    };
    programs.xwayland.enable = true;

    xdg.portal = {
      enable = true;
      wlr.enable = true;
    };

    # additional daemons to run in a Sway session
    systemd.user.targets.sway-session = {
      description = "Services that are only run by Sway";
      wants = [
        "gammastep.service"
        "mako.service"
      ];
    };
    systemd.user.services.gammastep = {
      description = "Redshift for Wayland";
      script = "${pkgs.gammastep}/bin/gammastep -b 1:0.5 -t 6500:2500 -l 51:13 -m wayland -r";
      serviceConfig.Restart = "always";
    };
    systemd.user.services.mako = {
      description = "Notification daemon";
      script = "${pkgs.mako}/bin/mako --font 'Iosevka 16' --width 400";
      serviceConfig.Restart = "always";
    };

    # enable IME for Japanese text
    i18n.inputMethod = {
      enabled = "fcitx";
      fcitx.engines = with pkgs.fcitx-engines; [ mozc ];
    };

    # systemd-networkd: do not block startup needlessly
    # TODO enable only on notebook
    systemd.network.wait-online.anyInterface = true;

    # systemd-logind: no magic suspend on lid close
    services.logind = {
      lidSwitch = "ignore";
      extraConfig = "HandlePowerKey=lock";
    };

    # development tools: Docker
    virtualisation.docker.enable = true;
    users.users.stefan.extraGroups = ["docker"];

    # gaming
    nixpkgs.config.allowUnfree = true;
    programs.steam.enable = true;
    hardware.steam-hardware.enable = true; # for Steam Controller

    # testing
    services.flatpak.enable = true;

  };

}
