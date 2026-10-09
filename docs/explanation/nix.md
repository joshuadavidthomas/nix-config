# About Nix

"Nix" names about ten separate things, and most confusion comes from mixing them up. When a
doc or blog post says "Nix", it helps to work out which layer it means first.

| Layer | What it is | Where it shows up here |
| --- | --- | --- |
| Nix language | A lazy, pure expression language. Every config is one big expression that evaluates to data. | Every `.nix` file |
| Nix tool and store | Builds *derivations* (build recipes) into immutable `/nix/store/<hash>-name` paths. Same inputs give the same path, so binaries come from a cache instead of being rebuilt. | `nix build`, `nix run`, garbage collection |
| nixpkgs | The package definitions plus all the NixOS modules. Its branches are the release channels (`nixos-26.05`, `nixpkgs-unstable`). | `pkgs.ripgrep`, [search.nixos.org](https://search.nixos.org) |
| Flakes | The entry point. `flake.nix` declares *inputs*, pinned in `flake.lock`, and *outputs*: machines, shells, packages. | This repo |
| Module system | Merges many small files into one typed tree of options. NixOS, nix-darwin, home-manager and devenv are all built on it. | `{ config, pkgs, ... }: { … }` |
| NixOS | A Linux distribution whose entire system is one module config. | The homelab, NixOS-WSL |
| nix-darwin | The same idea for macOS: system settings, launchd services, Homebrew. | The Mac |
| home-manager | User-level config: CLI tools, dotfiles, shell, git. Runs on top of any of the above. | Every machine |
| devenv | Per-project environments (languages, services, processes, hooks), also built on the module system. | Each project |
| Determinate Nix | A Nix distribution with flakes on by default and better macOS behavior. | The Mac |

## The store and generations

A package in Nix is a directory in `/nix/store` whose name starts with a hash of everything
that went into building it: the source, the compiler, every dependency, every flag. Change any
input and you get a different path, so two versions never overwrite each other, and anything
already built (by you or by the public cache) is reused instead of rebuilt.

A whole system works the same way. Each switch builds a complete system into the store, then
flips one symlink to point at it. The previous system, a *generation*, stays where it was, so
rolling back is just flipping the symlink back. It's also why the store only grows until
garbage collection removes generations nothing points at.

## Modules and how they merge

Every `.nix` file in `home/`, `hosts/` and `modules/` is a module: a set of option values, or
a function that returns one. Modules pull in other modules through `imports`, and the system
merges all of them into one tree. Lists concatenate, sets merge recursively, and two different
values for the same single-valued option is an error. `lib.mkDefault` and `lib.mkForce`
settle those conflicts by giving a value lower or higher priority.

This is why `home/josh.nix` can be shared. It sets what's the same everywhere, and each host
file adds or overrides what's different, without either file knowing about the other.

## Installing versus configuring

home-manager gives two ways to get a tool. `home.packages` only puts a binary on PATH.
`programs.<name>.enable` installs the package and also manages it: it writes the tool's
config file and wires up its shell integration. When home-manager has a module for a tool, the
module is the better choice, because the config then lives in Nix too. NixOS and nix-darwin
have the same split between `environment.systemPackages` and `programs.*`.

## Two command-line interfaces

Nix has an old CLI (`nix-env`, `nix-build`, `nix-shell`, channels) and a new one
(`nix build`, `nix run`, `nix develop`, flakes). This repo uses only the new one. The old one
still appears in older blog posts and in NixOS-WSL's first boot.

## Agents writing Nix

Coding agents write a lot of this repo's Nix. The most common failure is an option name that
doesn't exist, and evaluation catches that immediately, so an agent should run
`nix flake check` itself before calling a change done. It also pays to have it explain any
construct you can't read from the [syntax reference](../reference/nix-syntax.md). That's how
the config stays something you understand rather than something only the agent does.

## Further reading

- [Stop calling everything "Nix"](https://haskellforall.com/2022/08/stop-calling-everything-nix), on the layers
- [Zero to Nix](https://zero-to-nix.com), a flakes-first beginner path
- [nix.dev](https://nix.dev), the official tutorials, including the language tour
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world), a walkthrough of a flake-based NixOS and home-manager config
