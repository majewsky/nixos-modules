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
    boot.device = mkStrOpt "the device path for the EFI boot partition";      # e.g. "/dev/disk/by-uuid/xxx"
    root.device = mkStrOpt"the device path for the encrypted root partition"; # e.g. "/dev/disk/by-uuid/xxx"

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
    boot.initrd.luks.devices."root".device = cfg.root.device;
    fileSystems."/" = {
      device = "/dev/mapper/root";
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
        # - tried with "mtu 1508", but no effect (the ISP might negotiate us back down)
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
      # pppd will refuse to do anything unless someone sets the IFF_UP flag on the NIC,
      # and systemd-network will only do so if there is a matching network config
      name = cfg.wan.interface;
      linkConfig.ActivationPolicy = "up";
      # do not wait for a non-fe80 IP here, because this interface ain't getting any
      linkConfig.RequiredForOnline = false;
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
      networkConfig = {
        # configure IPv4 address statically
        Address = [ "10.0.0.${toString config.my.machineID}/24" ];
        # act as DHCPv4 server
        DHCPServer = true;
        # send RA based on delegated prefix on WAN
        IPv6AcceptRA = false;
        IPv6SendRA = true;
        DHCPPrefixDelegation = true;
        # TODO: announce smaller MTU
      };
      dhcpServerConfig = {
        ServerAddress = [ "10.0.0.${toString config.my.machineID}/24" ];
        PoolOffset = 100;
        PoolSize = 100;
        UplinkInterface = "ppp0";
        EmitDNS = true; # TODO: announce local resolved as DNS, open port 53 on LAN
        EmitNTP = false;
        EmitSIP = false;
      };
      # only ppp0 is relevant for systemd-networkd-wait-online.service
      linkConfig.RequiredForOnline = false;
    };

    # firewall configuration: allow LAN users to reach WAN (this requires manual sysctl for IPv6 forwarding,
    # because for some reason stock NixOS options only allow enable IPv6 forwarding when also enabling NATv6)
    networking.nftables.enable = true;
    networking.firewall = {
      backend = "nftables";
      filterForward = true;
      interfaces.${cfg.lan.interface}.allowedUDPPorts = [ 67 68 ]; # DHCPv4 server
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

  };

}
