# This module imports every other module in the repo root directory.
# REPLACES hologram-base
# REPLACES hologram-openssh

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my;

in {

  imports = [
    ./gitconfig.nix
    ./monitoring.nix
    ./nginx.nix
    ./static-websites.nix
    ./umurmur.nix
    /nix/my/unpacked/generated-basic.nix # supplies config.my.machineID and config.networking.hostname
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

    environment.systemPackages = with pkgs; [
      (pkgs.callPackage ./pkgs/bootstrap-devenv/default.nix {})
      (pkgs.callPackage ./pkgs/gofu/default.nix {})
      dnsutils # dig(1), host(1)
      gnumake # for decrypting the secrets in this repo
      gnupg   # for decrypting the secrets in this repo
      gptfdisk
      jq
      lsof
      nmap # ncat(1)
      openssl # for the openssl(1) utility tool
      pinfo
      pv
      ripgrep
      rsync
      screen
      strace
      tcpdump
      traceroute
      tree
      units
      vim
      wget
      zsh
    ];

    i18n = {
      consoleFont = "Lat2-Terminus16";
      consoleKeyMap = "us";
      defaultLocale = "de_DE.UTF-8";
      supportedLocales = [ "de_DE.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
    };

    time.timeZone = "Europe/Berlin";
    services.timesyncd.servers = [ "ptbtime1.ptb.de" ];

    boot.tmpOnTmpfs = true;
    services.openssh.enable = true;

    users.users.stefan = {
      isNormalUser = true;
      uid = 1000;
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

    # workaround for https://github.com/NixOS/nixpkgs/issues/47580 which will
    # be fixed in 19.03
    networking.firewall.interfaces.default = mkIf (config.system.stateVersion == "18.09") {
      allowedTCPPorts      = config.networking.firewall.allowedTCPPorts;
      allowedTCPPortRanges = config.networking.firewall.allowedTCPPortRanges;
      allowedUDPPorts      = config.networking.firewall.allowedUDPPorts;
      allowedUDPPortRanges = config.networking.firewall.allowedUDPPortRanges;
    };

  };

}
