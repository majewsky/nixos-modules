{ config, pkgs, lib, ... }:

with lib;

let

  optionsPerService = let
    mkFlag = description: mkOption {
      inherit description;
      type = types.bool;
      default = false;
    };
  in {
    allowUnixDomainSockets = mkFlag "allow service to use AF_UNIX sockets";
    allowInternetAccess = mkFlag "allow service to use AF_INET/AF_INET6 sockets";
    allowWriteAccessTo = mkOption {
      description = "List of paths that shall be mounted read-write (instead of read-only). If you use serviceConfig.{RuntimeDirectory,StateDirectory,CacheDirectory,LogsDirectory,ConfigurationDirectory}, those paths do not need to be mentioned again here.";
      type = types.listOf types.str;
      default = [];
    };
  };

  toSystemdServiceConfig = serviceName: opts: {
    serviceConfig = {
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RemoveIPC = true;
      ReadWritePaths = concatStringsSep " " opts.allowWriteAccessTo;
      RestrictAddressFamilies = (
        (optional opts.allowUnixDomainSockets "AF_UNIX")
        ++
        (optional opts.allowInternetAccess "AF_INET")
        ++
        (optional opts.allowInternetAccess "AF_INET6")
      );
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallErrorNumber = "EPERM";
      SystemCallFilter = "@system-service";
    };
  };

in {

  options.my.hardening = mkOption {
    description = "Which services to apply auto-hardening to. Each service mentioned in this attrset is, by default, restricted to a conservative set of syscalls (file IO, network IO, setuid/setgid etc.) that is useful for most network services, but does not allow tampering with the system configuration.";
    example = {
      gitea = { };
    };
    default = {};
    type = with types; attrsOf (submodule { options = optionsPerService; });
  };

  config.systemd.services = mapAttrs toSystemdServiceConfig config.my.hardening;

}
