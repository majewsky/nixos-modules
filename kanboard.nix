{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.my.services.kanboard;

in {

  options.my.services.kanboard = {
    domainName = mkOption {
      default = null;
      description = "domain name for Kanboard (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {
  };

}
