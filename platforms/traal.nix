# This module contains the hardware-specific configuration for my notebook.
# Most of it comes from the original </etc/nixos/hardware-configuration.nix>.
# TODO holodeck-traal

{ config, pkgs, lib, ... }:

with lib;

{

  imports = [
    <nixos-hardware/lenovo/thinkpad>
    <nixos-hardware/common/cpu/amd>
  ];

  config = {

    my.workstation.enabled = true;

    hardware.enableRedistributableFirmware = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.useDHCP = false;
    networking.interfaces.enp2s0.useDHCP = true;
    networking.interfaces.wlp4s0.useDHCP = true;

    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" "sdhci_pci" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    # NOTE: device paths are set in /etc/nixos/configuration.nix
    fileSystems."/" = {
      device = "/dev/mapper/root";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      # device = "...";
      fsType = "vfat";
    };
    # boot.initrd.luks.devices."root".device = "...";

    swapDevices = [];
    nix.maxJobs = mkDefault 8;

  };

}
