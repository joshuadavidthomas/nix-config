# Every NixOS machine: WSL, the lab boxes and VMs.
{ pkgs, ... }: {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = [ pkgs.git ];
}
