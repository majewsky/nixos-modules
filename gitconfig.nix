# This module sets up Git such that it does not complain about missing identity.
{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.programs.git;

in {

  options.my.programs.git = {
    userName = mkOption {
      default = "Stefan Majewsky";
      description = "value of user.name in /etc/gitconfig";
      type = types.string;
    };
    userEMail = mkOption {
      default = "majewsky@gmx.net";
      description = "value of user.email in /etc/gitconfig";
      type = types.string;
    };
  };

  config = {

    environment.systemPackages = with pkgs; [ git ];

    # silence Git's complaints about missing identity
    environment.etc."gitconfig".text = ''
      [user]
      name = ${cfg.userName}
      email = ${cfg.userEMail}
    '';

  };

}
