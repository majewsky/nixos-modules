# This module is imported by all my VMs on Hetzner Cloud.

{ config, pkgs, lib, ... }:

with lib; {

  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];

  options.my.hetzner-cloud = {
    ipv6Address = mkOption {
      description = "the IPv6 address for this machine (must end in ::1)";
      example = "2001:0db8:dead:beef::1";
      type = types.str;
    };
  };

  config = {
    # use Grub bootloader
    boot.loader.grub = {
      enable = true;
      version = 2;
      device = "/dev/sda";
    };

    # imported from the auto-generated /etc/nixos/hardware-configuration.nix
    boot.initrd.availableKernelModules = [
      "ata_piix" "uhci_hcd" "virtio_pci" "sd_mod" "sr_mod"
    ];
    fileSystems."/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };
    swapDevices = [];
    nix.maxJobs = lib.mkDefault 1;

    # network configuration: IPv4 comes via DHCP, but IPv6 must be given in via
    # the config (could theoretically be retrieved from the metadata service,
    # but we cannot use the network during nixos-rebuild)
    networking.interfaces.ens3.ipv6.addresses = [{
      address = config.my.hetzner-cloud.ipv6Address;
      prefixLength = 64;
    }];
    networking.defaultGateway6 = {
      address = "fe80::1";
      interface = "ens3";
    };

    # misc
    services.haveged.enable = true;
  };

}
