# nix-config

Nix configuration for my Macs, my work laptop (NixOS-WSL) and my homelab.

| Machine | Config | Apply |
| --- | --- | --- |
| Apple Silicon Mac | `hosts/mac` | `rebuild` |
| Work laptop | `hosts/work-wsl` | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| Homelab box | `hosts/lab-N` | `colmena apply` |

Set up a new Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
```

This repo uses jj. Use `jj describe` and `jj new`, not `git commit`.

See [docs](docs/README.md) and the [roadmap](docs/roadmap.md).
