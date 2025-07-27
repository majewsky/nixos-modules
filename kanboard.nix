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
    services.kanboard = {
      enable = true;
      domain = cfg.domainName;
      nginx = {
        forceSSL = true;
        enableACME = true;
        # TODO: extraConfig with security headers?
      };
      settings = let
        inherit (config.my) ldap;
        # workaround for <https://github.com/NixOS/nixpkgs/issues/428814>
        wrapInQuotes = text: "\"${text}\"";
      in {
        # TODO: why ain't this shit working!? it's not even TRYING to connect to the LDAP server
        LDAP_AUTH = "true";
        LDAP_SERVER = "ldaps://${ldap.domainName}"; # unclear whether explicit port specification is required
        LDAP_PORT = 636; # unclear if this is required when LDAP_SERVER contains a port

        LDAP_BIND_TYPE = "proxy";
        LDAP_USERNAME = wrapInQuotes "uid=${ldap.searchUserName},ou=users,${ldap.suffix}";
        LDAP_PASSWORD = ldap.searchUserPassword;

        LDAP_USER_CREATION = "true";
        LDAP_USER_BASE_DN = wrapInQuotes "ou=users,${ldap.suffix}";
        LDAP_USER_FILTER = wrapInQuotes "(&(uid=%s)(isMemberOf=cn=kanboard-users,ou=groups,${ldap.suffix}))";
        LDAP_USERNAME_CASE_SENSITIVE = "true";
        LDAP_USER_ATTRIBUTE_GROUPS = "isMemberOf";
        LDAP_GROUP_ADMIN_DN = wrapInQuotes "cn=kanboard-admins,ou=groups,${ldap.suffix}";
      };
    };
  };

}
