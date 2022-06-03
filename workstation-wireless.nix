# This module is enabled on mobile systems that have a WiFi interface.
{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.workstation;

in {

  options.my.workstation.wirelessInterfaces = mkOption {
    type = types.str;
    description = "Which network interfaces to configure wpa_supplicant for.";
    default = "";
    example = "wlp4s0";
  };

  config = mkIf (cfg.wirelessInterfaces != "") {
    networking.supplicant.${cfg.wirelessInterfaces} = {
      configFile.path = "/home/stefan/.wpa_supplicant.conf";
    };
  };

}
