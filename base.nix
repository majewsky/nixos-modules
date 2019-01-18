# This module is imported by every system, both headless servers and workstations.

{ config, pkgs, lib, ... }:

let
  cfg = config.majewsky.base;
in

with lib; {

  imports = [];

  options.majewsky.base.useSSHKeys = mkOption {
    default     = true;
    description = "whether to deploy /nix/my/secrets/ssh-keys-base to user 'stefan'";
    type        = lib.types.bool;
  };

  config = {
    i18n = {
      consoleFont = "Lat2-Terminus16";
      consoleKeyMap = "us";
      defaultLocale = "de_DE.UTF-8";
    };

    time.timeZone = "Europe/Berlin";
    services.openssh.enable = true;

    users.users.stefan = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keyFiles = mkIf cfg.useSSHKeys [
        /nix/my/secrets/ssh-keys-base
      ];
    };

    environment.systemPackages = with pkgs; [
      git
      gnumake
      gnupg
      vim
    ];
  };

}
