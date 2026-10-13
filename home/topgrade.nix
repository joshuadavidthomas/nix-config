# topgrade updates what Nix doesn't pin: Homebrew, npm and uv tools, the coding agents,
# Neovim plugins, rustup toolchains, and Determinate Nix on the Mac. Nix updates stay
# `nix flake update`, then rebuild (docs/changes.md).
{ lib, pkgs, ... }:
{
  programs.topgrade = {
    enable = true;
    settings.misc = {
      pre_sudo = true; # one password prompt at the start, not partway through
      disable = [
        "containers" # local images are pinned tags; pulling them gets nothing new
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        # `nixos-rebuild switch --upgrade` without --flake builds /etc/nixos, not this repo
        "system"
      ];
    };
    settings.commands.Amp = "amp update"; # topgrade has no built-in step for it
  };
}
