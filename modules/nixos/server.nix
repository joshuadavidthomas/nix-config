# Everything the homelab boxes have in common. Each hosts/lab-N adds its hostname, disk
# and generated hardware config.
{ pkgs, vars, ... }: {
  nix.settings.trusted-users = [ "root" vars.user ];
  nix.gc = { automatic = true; options = "--delete-older-than 30d"; };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.enableRedistributableFirmware = true; # NIC firmware and CPU microcode

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  users.users.${vars.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ vars.keys.controller ];
  };
  users.users.root.openssh.authorizedKeys.keys = [ vars.keys.controller ]; # colmena deploys as root
  security.sudo.wheelNeedsPassword = false;

  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  environment.systemPackages = [ pkgs.htop ];

  system.stateVersion = "26.05"; # set at install; never bump it
}
