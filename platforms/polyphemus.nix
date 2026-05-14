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
      "${cfg.wan.ppp.username}" * "@/nix/my/unpacked/pppoe-password"
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
        config = ''
          ifname wan
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

  };

}
