# nix-config

> Last reviewed: 2026-10-09

Nix configuration for my Macs, my work laptop (NixOS-WSL) and my homelab boxes. Every machine
gets its tools and settings from this repo.

## What's here

| Path | Purpose |
| --- | --- |
| `flake.nix` | Inputs, and one configuration for each kind of machine |
| `overlay.nix` | Where each package comes from: `nixpkgs-unstable` for command-line tools, the release for the rest |
| `pkgs/` | Packages that nixpkgs does not have, or has in an old version |
| `home/` | home-manager configuration for all machines |
| `hosts/mac/` | nix-darwin for all Apple Silicon Macs, and home-manager for the Mac only |
| `hosts/work-wsl/` | NixOS-WSL on the work laptop, with the work settings |
| `hosts/lab-N/` | One lab box: hostname, disk layout, hardware |
| `modules/server.nix` | Settings for all lab boxes |
| `secrets/` | Secrets, encrypted with sops |
| `bootstrap.sh` | Sets up a new Mac |
| `docs/` | Setup guides and tasks |
| `AGENTS.md` | Rules for coding agents |

### home/

| File | Purpose |
| --- | --- |
| `josh.nix` | Entry point: packages, PATH, shells |
| `cli.nix` | Command-line tools with settings (atuin, bat, direnv, tmux, …) |
| `git.nix` | git, gh and jj |
| `fish.nix`, `neovim.nix` | Shell and editor |
| `agents.nix` | Coding agents, their settings and hooks |
| `nix.nix` | Nix user settings and the GitHub token for Nix |
| `secrets.nix` | Gets the age key from 1Password |

## Why this setup

One description for every machine. A new Mac is one command, a new lab box is one install,
and a bad change is one rollback.

Nix installs the command-line tools and writes all settings. Homebrew installs only Mac apps.
Coding agents install and update themselves, because they release almost every day. Nix still
writes their settings.

## Usage

| Machine | Apply the configuration |
| --- | --- |
| Mac | `rebuild` |
| Work laptop | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| Lab boxes | `colmena apply`, on the Mac, in `~/.nix-config` |

## How to extend

### Add a command-line tool

1. Add it to `home.packages` in `home/josh.nix`.
2. Apply the configuration.

### Add a Mac app

1. Add it to `homebrew.casks` in `hosts/mac/default.nix`.
2. Run `rebuild`.

### Other changes

See [Changes](docs/changes.md) for the file that each change goes in.

### Add a machine

- [Set up a new Mac](docs/new-mac.md)
- [Set up NixOS-WSL](docs/new-wsl.md)
- [Set up a lab box](docs/new-lab-box.md)

## Dependencies

- Determinate Nix on the Mac. The bootstrap installs it.
- 1Password, for the SSH keys and the age key
- Tailscale, to reach the lab boxes
- jj, for version control. Nix installs it.

## Gotchas

- The repo uses jj. A `git commit` can come out empty. Use `jj describe` and `jj new`.
- After you add a file, run `jj status`. Until then, the flake does not see the file.
- On the Mac, a rollback removes Homebrew apps that the older generation does not declare. This
  can remove 1Password.
- SSH offers all the 1Password keys, and sshd stops after six. `~/.ssh/config` limits `lab-*` to
  `~/.ssh/lab.pub`. For other servers, set `IdentitiesOnly`.
- `colmena apply` works only in `~/.nix-config`.
- Nobody has applied `work-wsl` since October 2026.
- Never change `stateVersion`.

## Sync and backup

The repo is public on GitHub. Each machine has a clone at `~/.nix-config`. Secrets are in the
repo, encrypted. The age key and the SSH keys are in 1Password.

See [Secrets](docs/secrets.md).

## Related

- [nix-darwin options](https://nix-darwin.github.io/nix-darwin/manual/index.html)
- [home-manager options](https://home-manager-options.extranix.com)
- [NixOS options](https://search.nixos.org/options)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [colmena](https://colmena.cli.rs/unstable/)
