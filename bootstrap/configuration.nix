{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "TODO";

  i18n.defaultLocale = "de_DE.UTF-8";
  time.timeZone = "Europe/Berlin";
  services.openssh.enable = true;

  # minimal set of packages require to clone this repo and `make unpack`
  environment.systemPackages = with pkgs; [
    git
    gnumake
    gnupg
    vim
  ];

  users.users.stefan = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "TODO" ];
  };

  system.stateVersion = "20.03";
}
