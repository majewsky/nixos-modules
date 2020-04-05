{ config, pkgs, lib, ... }:

with lib;

{

  imports = [
    ./accessible.nix
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
  ];

  config = {

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

    swapDevices = [ ];
    nix.maxJobs = mkDefault 8;
    
  };

}
