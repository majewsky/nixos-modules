{ config, lib, pkgs, ... }: with lib; let
  cfg = {
    useEFI = false;
    hostName = "TODO";
    initialPublicKey = "TODO";
    buildupLAN = {
      enable = false;
      device = "enp1s0";
      address = "10.0.0.250/24";
      gateway = "10.0.0.1";
    };
  };
in {
  imports = [ ./hardware-configuration.nix ];

  boot.loader = if cfg.useEFI then {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  } else {
    grub.enable = true;
    grub.version = 2;
    grub.device = "/dev/sda";
  };

  networking.hostName = cfg.hostName;

  # optional static configuration of a LAN device for the buildup process
  networking.useDHCP = !cfg.buildupLAN.enable;
  networking.useNetworkd = cfg.buildupLAN.enable;
  systemd.network.enable = cfg.buildupLAN.enable;
  systemd.network.networks.buildup_lan = with cfg.buildupLAN; mkIf enable {
    name = device;
    address = [ address ];
    gateway = [ gateway ];
    dns = [ gateway ];
  };

  i18n = {
    defaultLocale = "de_DE.UTF-8";
    defaultCharset = "UTF-8";
    extraLocaleSettings.LC_MESSAGES = "C.UTF-8";
    extraLocales = [ "en_US.UTF-8/UTF-8" "C.UTF-8/UTF-8" ];
  };
  time.timeZone = "Europe/Berlin";

  services.openssh.enable = true;
  services.openssh.settings = {
    KbdInteractiveAuthentication = false;
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };

  # minimal set of packages require to clone this repo and `make unpack`;
  # also some network tools like ncat or rsync to send initial credentials over LAN if necessary
  environment.systemPackages = with pkgs; [
    age
    git
    gnumake
    nmap
    rsync
    vim
    wget
  ];

  users.users.stefan = {
    isNormalUser = true;
    uid = 1001;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ cfg.initialPublicKey ];
  };

  system.copySystemConfiguration = true;
  system.stateVersion = "25.11";
}
