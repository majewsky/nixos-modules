# This module contains the hardware-specific configuration for the homeserver.
# Most of it comes from the original </etc/nixos/hardware-configuration.nix>.

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.polyphemus;

in {

  imports = [
    <nixos-hardware/common/pc>
    <nixos-hardware/common/pc/ssd>
    <nixos-hardware/common/cpu/amd>
  ];

  options.my.polyphemus = let
    mkStrOpt = description: mkOption { inherit description; type = types.str; };
    mkStrOptWithDefault = default: description: mkOption { inherit description default; type = types.str; };
  in {
    boot.device = mkStrOpt "the device path for the EFI boot partition"; # e.g. "/dev/disk/by-uuid/xxx"
    root.device = mkStrOpt "the device path for the root partition";     # e.g. "/dev/disk/by-uuid/xxx"

    lan.interface = mkStrOptWithDefault "enp3s0" "the name of the LAN-facing ethernet interface";
    wan.interface = mkStrOptWithDefault "enp2s0" "the name of the WAN-facing ethernet interface";
    wan.ppp.username = mkStrOpt "the username for PPPoE on the WAN-facing ethernet interface";
    wan.ppp.peerName = mkStrOptWithDefault "sachsenenergie" "the name of the PPPoE peer in pppd";
  };

  config = {

    # additional host identity
    environment.variables = {
      PRETTYPROMPT_COMMONUSER = "stefan";
      PRETTYPROMPT_HOSTCOLOR = "0;31";
    };

    # boot loader
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # hardware support
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.enableRedistributableFirmware = lib.mkDefault true;
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # kernel modules
    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    # filesystems
    fileSystems."/" = {
      device = cfg.root.device;
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = cfg.boot.device;
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    # do not use networkmanager
    networking.useDHCP = false;
    networking.useNetworkd = true;
    systemd.network.enable = true;
    services.resolved.enable = true;

    # PPPoE on WAN
    environment.etc."ppp/pap-secrets".text = ''
      "${cfg.wan.ppp.username}" * "@/run/credentials/pppd-${cfg.wan.ppp.peerName}.service/pppoe-password"
    '';
    services.pppd = {
      enable = true;
      peers.${cfg.wan.ppp.peerName} = {
        enable = true;
        autostart = true;

        # config originally copied from <https://ipoac.nl/texts/pppd-systemd-networkd.html>,
        # with the following custom amendments:
        # - removed "up_sdnotify" since the NixOS module already sets this
        # - tried with "mtu 1508", but no effect (the ISP accepts "Max-Payload: 1500" during PPP Auto Discovery, but then negotiates us down during LCP)
        # - tried with "noipv6" and having networkd accept RA, but does not work for some reason (no /64 addrs configured and DHCPv6-PD is AWOL)
        config = ''
          ifname ppp0
          local
          noauth
          +ipv6
          defaultroute
          persist
          mtu 1500
          mru 1500
          plugin pppoe.so
          user "${cfg.wan.ppp.username}"
          nic-${cfg.wan.interface}
          lcp-echo-adaptive
        '';
      };
    };
    systemd.services."pppd-${cfg.wan.ppp.peerName}" = {
      # pppd.service is quite locked down, so it cannot read password files from just anywhere
      serviceConfig.LoadCredential = "pppoe-password:/nix/my/unpacked/pppoe-password";
    };
    systemd.network.networks.wan = {
      name = cfg.wan.interface;
      linkConfig = {
        # pppd will refuse to do anything unless someone sets the IFF_UP flag on the NIC,
        # and systemd-network will only do so if there is a matching network config
        ActivationPolicy = "up";
        # do not wait for a non-fe80 IP here, because this interface ain't getting any
        RequiredForOnline = false;
      };
    };

    # network configuration of PPP link: pppd by itself does RA and gives us /64 addresses,
    # but for routing IPv6 to downstream LANs, we need a larger subnet via DHCPv6-PD
    systemd.network.networks.ppp = {
      matchConfig.Type = "ppp";
      linkConfig = {
        ActivationPolicy = "manual";
        RequiredForOnline = "no";
      };
      networkConfig = {
        DHCP = "ipv6";
        DHCPPrefixDelegation = true; # this is also needed on the same interface where PD was performed, or we have no public IPv6 addresses at all
        IPv6AcceptRA = false;
        DNSDefaultRoute = true;
        # options for resiliency against systemd-networkd reload or restart
        KeepConfiguration = "static"; # do not remove IPv4 address provisioned by pppd
        DefaultRouteOnDevice = true;  # systemd-networkd will still kill the IPv4 default route, so make it add its own one (i.e. we sometimes get two, but whatever)
      };
      dhcpV6Config = {
        WithoutRA = "solicit";
        PrefixDelegationHint = "::/56";
      };
      routes = [
        { Gateway = "::"; } # setup the IPv6 default route through this interface (pppd does the IPv4 default route)
      ];
    };

    # network configuration of LAN link
    systemd.network.networks.lan = {
      name = cfg.lan.interface;
      linkConfig = {
        # only ppp0 is relevant for systemd-networkd-wait-online.service
        RequiredForOnline = false;
      };
      networkConfig = {
        # configure IPv4 address statically
        Address = [ "10.0.0.${toString config.my.machineID}/24" ];
        # act as DHCPv4 server
        DHCPServer = true;
        # send RA based on delegated prefix on WAN
        IPv6AcceptRA = false;
        IPv6SendRA = true;
        DHCPPrefixDelegation = true;
      };
      dhcpServerConfig = {
        ServerAddress = [ "10.0.0.${toString config.my.machineID}/24" ];
        PoolOffset = 100;
        PoolSize = 100;
        UplinkInterface = "ppp0";
        EmitDNS = true;
        DNS = [ "_server_address" ]; # dnsmasq listens here (see below)
        EmitNTP = false;
        EmitSIP = false;
      };
    };

    # firewall configuration: allow LAN users to reach WAN (this requires manual sysctl for IPv6 forwarding,
    # because for some reason stock NixOS options only allow enable IPv6 forwarding when also enabling NATv6)
    networking.nftables.enable = true;
    networking.firewall = {
      backend = "nftables";
      filterForward = true;
      interfaces.${cfg.lan.interface}.allowedUDPPorts = [ 53 67 68 ]; # DNS and DHCPv4 servers
      # enable MSS clamping to fix path MTU discovery
      # Ref: <https://wiki.nftables.org/wiki-nftables/index.php/Mangling_packet_headers>
      # Ref: <https://k1024.org/posts/2023/2023-04-16-nftables-tcp-clamp-mss/>
      extraForwardRules = ''
        iifname ppp0 tcp flags syn tcp option maxseg size set rt mtu counter comment "enable MSS clamping"
        oifname ppp0 tcp flags syn tcp option maxseg size set rt mtu counter comment "enable MSS clamping"
      '';
    };
    networking.nat = {
      enable = true;
      externalInterface = "ppp0";
      internalInterfaces = [ cfg.lan.interface ];
    };
    boot.kernel.sysctl = {
      "net.ipv6.conf.all.forwarding" = true;
      "net.ipv6.conf.default.forwarding" = true;
      # do not prevent IPv6 autoconfiguration
      # Ref: <http://strugglers.net/~andy/blog/2011/09/04/linux-ipv6-router-advertisements-and-forwarding/>
      "net.ipv6.conf.all.accept_ra" = 2;
      "net.ipv6.conf.default.accept_ra" = 2;
    };

    # FIXME: sometimes (TM) the IPv6 addresses on ppp0 get lost and I'm not sure why yet;
    # for now, as a workaround, restart pppd every once in a while to wipe the slate clean
    systemd.services.restart-pppd = {
      script = "${getBin pkgs.systemd}/bin/systemctl restart pppd-${cfg.wan.ppp.peerName}.service";
      startAt = "03:30";
    };

    # network configuration: dnsmasq serves local DNS with adblocking for security (no DHCP, systemd-networkd does that already)
    services.dnsmasq = {
      enable = true;
      alwaysKeepRunning = true;
      resolveLocalQueries = false; # systemd-resolved does that

      settings = {
        bind-interfaces = true; # do not bind on 0.0.0.0 and [::] to avoid conflict with systemd-resolved
        interface = cfg.lan.interface;
        except-interface = "lo"; # systemd-resolved listens here

        addn-hosts = "/var/lib/adblock/hosts.txt";

        # NOTE: dnssec must be disabled because it does not work with the ISP nameservers for some reason
        #
        # dnssec = true;
        # # source: <https://data.iana.org/root-anchors/root-anchors.xml>
        # trust-anchor = ".,19036,8,2,49AAC11D7B6F6446702E54A1607371607A1A41855200FD2CE1CDDE32F24E8FB5";
      };
    };
    systemd.services.dnsmasq.enableStrictShellChecks = false; # TODO 26.11: check if still needed

    # for dnsmasq: ensure that /var/lib/adblock/hosts.txt always exists
    system.activationScripts.adblock-hosts-file = ''
      install -d -m 0755 -o dnsmasq -g dnsmasq /var/lib/adblock
      if [ ! -f /var/lib/adblock/hosts.txt ]; then
        install -m 0755 -o dnsmasq -g dnsmasq /dev/null /var/lib/adblock/hosts.txt
      fi
    '';

    # cronjob to download the adblock host list every once in a while
    systemd.services.adblock-sync = {
      startAt = "03:35"; # after restart-pppd above

      # This part of the cronjob needs to run as root to reload dnsmasq.service,
      # but we want the actual download to run with low privileges.
      script = "systemctl start adblock-sync-lowpriv && systemctl stop dnsmasq";
    };
    systemd.services.adblock-sync-lowpriv = {
      path = [ pkgs.wget ];
      script = ''
        cd /var/lib/adblock
        wget -O downloaded.txt https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts || exit 1
        grep '^0.0.0.0 ' < downloaded.txt | grep -v '^0.0.0.0 0.0.0.0' | sort -u > hosts.txt.new
        mv hosts.txt.new hosts.txt
      '';

      serviceConfig = {
        Type = "oneshot"; # to ensure that dnsmasq.service is only reloaded once the script above is done

        WorkingDirectory = "/var/lib/adblock";
        User = "dnsmasq";
        Group = "dnsmasq";

        # hardening
        ReadOnlyPaths = "/";
        ReadWritePaths = "/var/lib/adblock";
        NoExecPaths = "/";
        ExecPaths = "/nix/store";

        PrivateDevices = true;
        PrivateIPC = true;
        PrivateMounts = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;

        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        SystemCallFilter = "@system-service";
      };
    };
  };

}
