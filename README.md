# nix-config

Nix configuration for my Macs, my work laptop (NixOS-WSL) and my homelab boxes.

```text
flake.nix          inputs, and one configuration for each kind of machine
overlay.nix        where each package comes from
pkgs/              packages that nixpkgs does not have
home/              home-manager configuration for all machines
hosts/mac/         Macs (nix-darwin)
hosts/work-wsl/    work laptop (NixOS-WSL)
hosts/lab-N/       one lab box (NixOS)
modules/server.nix settings for all lab boxes
secrets/           secrets, encrypted with sops
bootstrap.sh       sets up a new Mac
```

## Set up a machine

- [A new Mac](docs/new-mac.md)
- [NixOS-WSL](docs/new-wsl.md)
- [A lab box](docs/new-lab-box.md)

## Work in the repo

- [Changes](docs/changes.md): where a change goes, apply, update, roll back
- [Secrets](docs/secrets.md)
