# This module contains the basic options and setup for connecting to my LDAP server.
{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.ldap;

in {

  # NOTE: the domainName and suffix options are also consumed by other modules
  options.my.ldap = {
    ipAddress = mkOption {
      description = "IP address of LDAP server";
      type = types.str;
    };
    domainName = mkOption {
      description = "domain name of LDAP server";
      type = types.str;
    };
    suffix = mkOption {
      description = "root DN suffix of LDAP server";
      type = types.str;
    };
  };

  config = {
    # in DNS, the LDAP domain name refers to the public IPs of that server
    # because of ACME; we want to use the internal IP instead (the LDAP server
    # is not reachable through the public IP)
    networking.hosts.${cfg.ipAddress} = [ cfg.domainName ];
  };

}
