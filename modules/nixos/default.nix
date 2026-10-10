# Every NixOS machine: WSL, the lab boxes and VMs.
{ pkgs, vars, ... }: {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.fish.enable = true;
  users.users.${vars.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  # home-manager's switch reads secrets that opnix writes (atuin's login), so it waits for opnix
  systemd.services."home-manager-${vars.user}" = {
    wants = [ "opnix-secrets.service" ];
    after = [ "opnix-secrets.service" ];
  };

  # prebuilt Linux binaries need a standard dynamic loader: the coding agents' installers,
  # uv's Python builds, VS Code's WSL server
  programs.nix-ld.enable = true;

  environment.systemPackages = [ pkgs.git ];
}
