{
  imports = [
    ../../modules/nixos/server.nix
    ../../modules/nixos/single-disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
  ];

  networking.hostName = "lab-2";
}
