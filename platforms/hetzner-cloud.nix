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

    rootDeviceUUID = mkOption {
      default = null;
      description = "device UUID for the root filesystem partition";
      example = "6f296c44-4686-43c6-b27e-b7af28818f1a";
      type = types.nullOr types.str;
    };
  };

  config = {
    # use Grub bootloader
    boot.loader.grub = {
      enable = true;
      device = "/dev/sda";
    };

    # imported from the auto-generated /etc/nixos/hardware-configuration.nix
    boot.initrd.availableKernelModules = [
      "ata_piix" "uhci_hcd" "virtio_pci" "sd_mod" "sr_mod"
    ];
    fileSystems."/" = let uuid = config.my.hetzner-cloud.rootDeviceUUID; in {
      device = if uuid == null then "/dev/sda1" else "/dev/disk/by-uuid/${uuid}";
      fsType = "ext4";
    };
    swapDevices = [];
    nix.settings.max-jobs = lib.mkDefault 1;

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

    # as of 24.11, the default start script for this unit does not pass shellcheck(1)
    systemd.services.network-addresses-ens3.enableStrictShellChecks = false;

    # misc
    services.haveged.enable = true;
  };

}
