# Machines where you write code: the Mac and WSL. Adds language toolchains, the coding
# agents, the ~/.nix-config checkout and the age key from 1Password to home/core.
{ pkgs, ... }: {
  imports = [
    ./agents.nix
    ./nix.nix
    ./secrets.nix
  ];

  home.packages = with pkgs; [
    bun
    cargo-binstall
    devenv
    go_1_27
    lisette
    lua5_5
    nodejs_24
    pnpm_12
    python314 # default python3; projects pin their own with uv/devenv
    rustup
    zig
  ];
}
