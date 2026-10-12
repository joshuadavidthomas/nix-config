{ inputs, ... }: {
  imports = [
    ../../modules/nixos/server.nix
    ../../modules/nixos/single-disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
    inputs.yonder.nixosModules.default
  ];

  networking.hostName = "lab-1";

  # yonderd, so a reboot, a reinstall or `colmena apply` brings it back. The module also
  # enables systemd-resolved (.internal on the box), turns off SNAT on Tailscale subnet
  # routes, and keeps dhcpcd off yonder's interfaces. The daemon advertises its own guest
  # routes; tag:lab's are approved by the tailnet policy (tailscale-acls).
  services.yonder.enable = true;
}
