{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.my.services.jitsi-meet;

in {

  options.my.services.jitsi-meet = {
    domainName = mkOption {
      default = null;
      description = "domain name for Jitsi Meet (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    # ref: <https://github.com/NixOS/nixpkgs/pull/334638>
    nixpkgs.config.permittedInsecurePackages = [ "jitsi-meet-1.0.8043" ];

    services.jitsi-meet = {
      enable = true;
      hostName = cfg.domainName;
      config = {
        enableWelcomePage = false;
        prejoinPageEnabled = true;
        defaultLang = "de";
      };
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
      };
    };

    services.jitsi-videobridge.openFirewall = true;

  };

}
