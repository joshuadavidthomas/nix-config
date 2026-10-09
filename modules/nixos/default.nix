# Every NixOS machine: WSL, the lab boxes and VMs.
{ pkgs, vars, ... }: {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.fish.enable = true;
  users.users.${vars.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  environment.systemPackages = [ pkgs.git ];
}
