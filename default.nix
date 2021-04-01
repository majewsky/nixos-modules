# This module imports every other module in the repo root directory.
# REPLACES hologram-base
# REPLACES hologram-openssh

# TODO https://gitlab.com/simple-nixos-mailserver/nixos-mailserver

{ config, pkgs, lib, ... }:

with lib;

let

  gofu = pkgs.callPackage ./pkgs/gofu/default.nix {};

  bootstrap-devenv = pkgs.writeScriptBin "bootstrap-devenv" ''
    #!/usr/bin/env bash
    set -euo pipefail

    REPO_URL=github.com/majewsky/devenv
    REPO_SHORT_URL=gh:majewsky/devenv
    export GOPATH=/x

    # clone devenv repo into the (not yet populated) repo tree
    REPO_PATH="$GOPATH/src/$REPO_URL"
    if [ ! -d "$REPO_PATH/.git" ]; then
        git clone "https://$REPO_URL" "$REPO_PATH"
        # this remote URL will become valid as soon as the devenv is installed
        git -C "$REPO_PATH" remote set-url origin "$REPO_SHORT_URL"
    fi

    # run setup script for devenv
    "$REPO_PATH/install.sh"

    # add the devenv repo to the rtree index (if not done yet)
    rtree get "$REPO_SHORT_URL" > /dev/null
  '';

in {

  imports = [
    ./alltag.nix
    ./archlinux-mirror.nix
    ./borgbackup-sender.nix
    ./gitconfig.nix
    ./gitea.nix
    ./grafana.nix
    ./hardening.nix
    ./jitsi-meet.nix
    ./ldap-client.nix
    ./ldap-server.nix
    ./matrix-synapse.nix
    ./minecraft-server.nix
    ./monitoring.nix
    ./nextcloud.nix
    ./nginx.nix
    ./nginx-minimal-logging.nix
    ./plain-websites.nix
    ./prometheus.nix
    ./prosody.nix
    ./static-websites.nix
    ./umurmur.nix
    ./vt6-website.nix
    ./workstation.nix
    /nix/my/unpacked/generated-basic.nix # supplies config.my.machineID and config.networking.hostName (among others)
  ];

  options.my = {

    machineID = mkOption {
      description = "machine ID (appears in autogenerated IP addresses etc.)";
      type = types.ints.u8;
    };

  };

  config = {
    ############################################################################
    # package overrides (copy-pasted from j03, thx!)

    nixpkgs.config.packageOverrides = pkgs: {
      channels = {
        # It seems like numeric channel names are not updated correctly to
        #   /nix/var/nix/profiles/per-user/root/channels/
        # when using:
        #   nixos-rebuild switch --upgrade
        # however this works:
        #   nix-channel --update

        ## nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable
        unstable = import <nixos-unstable>
          { config = config.nixpkgs.config; };
        ## nix-channel --add https://nixos.org/channels/nixos-18.09 nixos-eighteen-nine
        # nix1809 = import <nixos-eighteen-nine>
        #   { config = config.nixpkgs.config; };
      };
    };

    ############################################################################
    # basic setup for interactive use

    system.autoUpgrade.enable = mkDefault true;
    nix.gc = {
      automatic = mkDefault true;
      options = "--delete-older-than 3d";
    };

    environment.systemPackages = with pkgs; [
      bootstrap-devenv
      dnsutils # dig(1), host(1)
      file
      gnumake # for decrypting the secrets in this repo
      gnupg   # for decrypting the secrets in this repo
      gofu
      gptfdisk
      jq
      lsof
      nmap # ncat(1)
      openssl # for the openssl(1) utility tool
      pinfo
      pwgen
      pv
      ripgrep
      rsync
      screen
      strace
      tcpdump
      traceroute
      tree
      units
      (if config.my.workstation.enabled then vimHugeX else vim)
      wget
      zsh
    ];

    i18n = {
      defaultLocale = "de_DE.UTF-8";
      extraLocaleSettings.LC_MESSAGES = "C";
      supportedLocales = [ "de_DE.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
    };

    time.timeZone = "Europe/Berlin";
    services.timesyncd.servers = [ "ptbtime1.ptb.de" ];

    boot.tmpOnTmpfs = true;
    services.openssh.enable = true;

    users.users.stefan = {
      isNormalUser = true;
      uid = 1001;
      extraGroups = ["wheel"];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keyFiles = [ /nix/my/unpacked/ssh-keys ];
    };

    programs.zsh = {
      # make zsh work as a login shell; cf. https://github.com/NixOS/nixpkgs/issues/20548
      enable = true;

      # use my own prompt
      promptInit = "";
    };

    # limit disk usage of persistent syslog
    services.journald.extraConfig = ''
      SystemMaxUse=512M
    '';

  };

}
