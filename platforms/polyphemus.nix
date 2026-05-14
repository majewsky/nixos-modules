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

  options.my.polyphemus = {
    boot.device = mkOption {
      description = "the device path for the EFI boot partition";
      example = "/dev/sda1";
      type = types.str;
    };
    root.device = mkOption {
      description = "the device path for the encrypted root partition";
      example = "/dev/sda2";
      type = types.str;
    };
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

  };

}
