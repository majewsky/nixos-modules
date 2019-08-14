# This module deploys Taiga, a project management software.
{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.taiga;

  internalBackendListenPort = 17695;

  taiga-backend-package = pkgs.callPackage ./pkgs/taiga-backend/default.nix {};

in {

  options.my.services.taiga = {
    domainName = mkOption {
      default = null;
      description = "domain name for Taiga (must be given to enable the service)";
      type = types.nullOr types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {

    containers.taiga = {
      autoStart = true;
      forwardPorts = [{
        containerPort = internalBackendListenPort;
        hostPort = internalBackendListenPort;
      }];
      privateNetwork = true;
      hostAddress = "192.168.100.1";
      localAddress = "192.168.100.2";

      config = {config, pkgs, lib, ... }: with lib; {

        environment.systemPackages = with pkgs; [
          postgresql_11 # for psql(1)
          taiga-backend-package
        ];

        users.groups.taiga.gid = 1000;
        users.users.taiga = {
          uid = 1000;
          group = "taiga";
          home = "/";
          shell = pkgs.bashInteractive;
        };

        services.postgresql = {
          enable = true;
          dataDir = "/var/lib/postgresql";
          package = pkgs.postgresql_11;
          initialScript = pkgs.writeText "taiga-postgres-init.sql" ''
            CREATE USER taiga;
            CREATE DATABASE taiga OWNER taiga ENCODING 'utf-8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0;
          '';
        };

        # TODO: continue with https://taigaio.github.io/taiga-doc/dist/setup-production.html#_backend_configuration

      };
    };

  };

}
