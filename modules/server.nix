# Everything the homelab boxes have in common. Each hosts/lab-N adds its hostname, disk
# and generated hardware config.
{ pkgs, ... }:
let
  # the "Mac mini" key in 1Password; hosts/mac/home.nix points ssh at the same key
  controller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVCdVXgBfljpv3nqraSApsBRM7Lg5U/L8HIXTNXesBn";
in
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "josh" ];
  nix.gc = { automatic = true; options = "--delete-older-than 30d"; };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.enableRedistributableFirmware = true; # NIC firmware and CPU microcode

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  users.users.josh = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ controller ];
  };
  users.users.root.openssh.authorizedKeys.keys = [ controller ]; # colmena deploys as root
  security.sudo.wheelNeedsPassword = false;

  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  environment.systemPackages = with pkgs; [ git htop ];

  system.stateVersion = "26.05"; # set at install; never bump it
}
