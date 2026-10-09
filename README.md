# nix-config

Every machine I use, in one flake. All of them share the home-manager config in `home/`, and
projects can reuse its package choices from devenv.

| Machine | Config | Apply with |
| --- | --- | --- |
| Any Apple Silicon Mac | `hosts/mac` | `rebuild` |
| Work laptop (NixOS-WSL) | `hosts/work-wsl` | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| Homelab boxes | `hosts/lab-N`, `modules/server.nix` | `colmena apply` |

A new Mac needs one command ([details](docs/how-to/set-up-a-mac.md)):

```sh
curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
```

Version control is jj: use `jj describe -m "…"` and `jj new` rather than `git commit`.

The [docs](docs/README.md) have a tutorial, how-to guides for setting up each kind of machine,
reference pages, and explanations of how the repo is designed and how it got this way. The
[roadmap](docs/roadmap.md) tracks what's left.
