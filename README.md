# nix-config

This repo configures my machines with Nix: Apple Silicon Macs, a work laptop on NixOS-WSL,
and homelab boxes. One home-manager configuration in `home/` is shared by all of them.
Comments in the code explain each decision.

| Machine | Configuration | Apply |
| --- | --- | --- |
| Mac | `hosts/mac` | `rebuild` |
| Work laptop (WSL) | `hosts/work-wsl` | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| Lab box | `hosts/lab-N`, `modules/server.nix` | `colmena apply`, on the Mac, in `~/.nix-config` |

## Where a change goes

| To add or change | Edit |
| --- | --- |
| A command-line tool, on all machines | `home.packages` in `home/josh.nix` |
| A tool that is already configured | The file in `home/` that configures it |
| A coding agent, or its settings and hooks | `home/agents.nix` |
| A tool or setting on the Mac only | `hosts/mac/home.nix` |
| A Mac app | `homebrew.casks` in `hosts/mac/default.nix` |
| A Homebrew formula that nixpkgs does not have | `homebrew.brews` and `taps` in `hosts/mac/default.nix` |
| A macOS setting | `system.defaults` in `hosts/mac/default.nix` |
| A work setting | `hosts/work-wsl/default.nix` |
| A setting on all lab boxes | `modules/server.nix` |
| A setting on one lab box | `hosts/lab-N/default.nix` |
| The source of a package (release or unstable) | `overlay.nix` |
| A package that nixpkgs does not have | `pkgs/`. See [Changes](docs/changes.md#add-a-package-that-nixpkgs-does-not-have). |
| A secret | `secrets/`. See [Secrets](docs/secrets.md). |

## Rules

- Use jj, not git. Record a change with `jj describe -m "…"`, then `jj new`.
- After you add a file, run `jj status`. The flake does not see a file before jj records it.
- Run `nix flake check` before you record a change.
- Keep secrets out of `.nix` files.
- Never change `stateVersion`.

## Docs

- [Set up a new Mac](docs/new-mac.md)
- [Set up NixOS-WSL](docs/new-wsl.md)
- [Set up a lab box](docs/new-lab-box.md)
- [Changes](docs/changes.md): apply, update, roll back
- [Secrets](docs/secrets.md)

Options: [NixOS](https://search.nixos.org/options),
[home-manager](https://home-manager-options.extranix.com),
[nix-darwin](https://nix-darwin.github.io/nix-darwin/manual/index.html).
