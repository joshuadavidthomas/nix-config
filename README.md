# nix-config

Every machine I use, in one flake. All of them share the home-manager config in `home/`.
[docs/all-in-on-nix.md](docs/all-in-on-nix.md) explains how it got here: the plan, what each
phase turned into, the problems hit along the way, and what's still open.

| Machine | Config | Apply with |
| --- | --- | --- |
| Any Apple Silicon Mac | `hosts/mac` | `rebuild` |
| Work laptop (NixOS-WSL) | `hosts/work-wsl` | `sudo nixos-rebuild switch --flake .#work-wsl` |
| Homelab boxes | `hosts/lab-N`, `modules/server.nix` | `colmena apply`; see [docs/homelab.md](docs/homelab.md) |

## New Mac

```sh
curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
```

It installs Determinate Nix, applies the config, waits for you to sign in to 1Password, then
applies it again to put the secrets in place. `bootstrap.sh` explains each step.

## Working in this repo

- **Version control is jj.** Use `jj describe -m "…"` and `jj new`, not `git commit`.
- **Secrets** are encrypted with sops in `secrets/`. Edit them with `sops secrets/secrets.yaml`.
  The age key that opens them is in 1Password. A Mac fetches it on its first switch; elsewhere
  it has to be placed at `~/.config/sops/age/keys.txt` by hand.
- **Upgrade everything** with `nix flake update`, then apply. To undo a bad upgrade, restore
  `flake.lock` from the previous change and apply again.
