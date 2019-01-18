# This module is imported by all my VMs on Hetzner Cloud.

{ config, pkgs, lib, ... }:

with lib; {

  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    ./base.nix
  ];

  config = {
    # use different SSH keys for access to Hetzner Cloud instances
    majewsky.base.useSSHKeys = false;
    users.users.stefan.openssh.authorizedKeys.keyFiles = [
      /nix/my/secrets/ssh-keys-hetzner
    ];

    # use Grub bootloader
    boot.loader.grub = {
      enable = true;
      version = 2;
      device = "/dev/sda";
    };

    # imported from the auto-generated /etc/nixos/hardware-configuration.nix
    boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "sd_mod" "sr_mod" ];
    fileSystems."/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };
    swapDevices = [];
    nix.maxJobs = lib.mkDefault 1;
  };

}
