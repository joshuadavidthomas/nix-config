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

## Rules for changes

- This repo uses jj. Use `jj describe` and `jj new`, not `git commit`.
- After you add a file, run `jj status`. The flake does not see a file until jj records it.
- Run `nix flake check` before you record a change.
- Do not change a `stateVersion`.

## Docs

- [Basics](docs/basics.md): layout, applying, updating, rolling back
- [Mac](docs/mac.md)
- [WSL](docs/wsl.md)
- [Homelab](docs/homelab.md)
- [Secrets](docs/secrets.md)
