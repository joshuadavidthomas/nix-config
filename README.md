# nix-config

Nix configuration for my Macs, my work laptop and my homelab.

## What this does

Every machine I use gets its tools and settings from this repo. A new Mac is one command, a
new homelab box is one install, and a bad change is one rollback. I built it to stop setting
up each machine by hand.

## Tech stack

| Part | Technology |
| --- | --- |
| Package manager | [Nix](https://nixos.org), with flakes. Determinate Nix on the Mac. |
| Mac | [nix-darwin](https://github.com/nix-darwin/nix-darwin), with Homebrew for Mac apps |
| Work laptop | [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) |
| Homelab | NixOS, installed with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and updated with [colmena](https://colmena.cli.rs) over Tailscale |
| User settings | [home-manager](https://github.com/nix-community/home-manager), shared by all machines |
| Secrets | 1Password, read with [opnix](https://github.com/brizzbuzz/opnix) and a service account |
| Version control | [jj](https://github.com/jj-vcs/jj) |

## Getting started

Set up a new Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
```

Then apply changes with:

| Machine | Command |
| --- | --- |
| Mac | `rebuild` |
| Work laptop | `rebuild` |
| Homelab | `colmena apply`, on the Mac, in `~/.nix-config` |

Docs:

- [Set up a new Mac](docs/new-mac.md)
- [Set up NixOS-WSL](docs/new-wsl.md)
- [Set up a lab box](docs/new-lab-box.md)
- [Make a change](docs/changes.md)
- [Secrets](docs/secrets.md)
- [Decisions](docs/decisions.md)
- [Roadmap](docs/roadmap.md)

Research:

- [Homelab monitoring](docs/research/homelab-monitoring.md)

## How it works

`flake.nix` has one configuration for each kind of machine: `mac` for all Apple Silicon Macs,
`work-wsl`, and `lab-1`, `lab-2` and so on. `lib/mksystem.nix` builds each of them the same
way: the overlay, the base module for the OS in `modules/`, and home-manager with `home/` for
the user. So every machine has the same shells, tools, languages and coding agents.
`hosts/<name>/` adds what only that machine or platform can have, such as Mac apps or WSL
interop. The lab boxes share `modules/nixos/server.nix`. Values that more than one machine
uses, such as the username and the public keys, are in `vars.nix`.

`overlay.nix` selects the source of each package. Command-line tools come from
`nixpkgs-unstable`. Runtimes and libraries come from the release. Packages that nixpkgs does not
have are in `pkgs/`.

Coding agents (Claude Code, Codex, opencode, pi) install and update themselves. Nix only makes
sure that they are installed, and writes their settings.

Secrets are in 1Password, not in the repo. On every machine, opnix reads them with a
1Password service account and writes each one to a file. An apply copies the service account
token from 1Password to the machine. `modules/secrets.nix` declares the secrets.

## License

[MIT](LICENSE).
