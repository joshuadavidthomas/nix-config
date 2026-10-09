{
  imports = [
    ../../modules/server.nix
    ./disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
  ];

  networking.hostName = "lab-2";
}
