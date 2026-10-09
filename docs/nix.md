# What "Nix" means

"Nix" is the name of about ten different things. When a document says "Nix", first find which
one it means.

| Name | What it is | Where this repo uses it |
| --- | --- | --- |
| Nix language | A lazy, pure language. Each configuration is one expression that gives data. | Every `.nix` file |
| Nix and the store | The tool that builds packages into `/nix/store/<hash>-name`. The same inputs give the same path, so Nix can download a build instead of doing it again. | `nix build`, `nix run`, garbage collection |
| nixpkgs | The package definitions and the NixOS modules. Its branches are the releases (`nixos-26.05`, `nixpkgs-unstable`). | `pkgs.ripgrep` |
| Flakes | The entry point. `flake.nix` lists the *inputs*, pinned in `flake.lock`, and the *outputs*: machines, shells and packages. | This repo |
| Module system | Merges many files into one tree of typed options. NixOS, nix-darwin, home-manager and devenv use it. | `{ config, pkgs, ... }: { … }` |
| NixOS | A Linux distribution that one module configuration describes. | The homelab, NixOS-WSL |
| nix-darwin | The same for macOS: settings, launchd services, Homebrew. | The Mac |
| home-manager | Configuration for one user: tools, dotfiles, shell, git. It runs on all of the above. | Every machine |
| devenv | Environments for projects: languages, services, processes and hooks. | Each project |
| Determinate Nix | A Nix distribution with flakes on and better macOS support. | The Mac |

## The store and generations

Nix puts each package in its own directory in `/nix/store`. The directory name starts with a
hash of all the build inputs: source, compiler, dependencies and flags. If one input changes,
the path changes. Two versions of a package never overwrite each other. If a path already
exists, locally or in the public cache, Nix does not build it again.

A full system works the same way. Each switch builds a new system in the store, then changes
one symlink to point to it. The old system stays in the store. It is called a *generation*. A
rollback changes the symlink back. Old generations use disk space until garbage collection
removes them.

## Modules

Each `.nix` file in `home/`, `hosts/` and `modules/` is a module. A module sets options, and
can import other modules. Nix merges all the modules into one tree:

- Lists join together.
- Sets merge.
- Two different values for one single-value option cause an error. `lib.mkDefault` and
  `lib.mkForce` give a value lower or higher priority.

Because of this, the machines can share `home/josh.nix`. It sets what is the same on all
machines. Each host file adds or changes what is different.

## Packages and programs

home-manager has two ways to add a tool:

- `home.packages` puts the program on PATH.
- `programs.<name>.enable` puts the program on PATH and also writes its configuration and
  shell integration.

If home-manager has a module for the tool, use the module. Then the tool's configuration is
in Nix too. NixOS and nix-darwin have the same two ways: `environment.systemPackages` and
`programs.*`.

## The two command-line interfaces

Nix has an old CLI (`nix-env`, `nix-build`, `nix-shell`, channels) and a new CLI (`nix build`,
`nix run`, `nix develop`, flakes). This repo uses only the new CLI. You see the old CLI in old
blog posts and in the first boot of NixOS-WSL.

## Nix from coding agents

Coding agents write much of the Nix in this repo. Their most frequent error is an option name
that does not exist. Evaluation finds this error at once, so tell the agent to run
`nix flake check` before it finishes. Also tell it to explain each construct that is not in
the [syntax reference](nix-syntax.md). Then you understand the configuration too.

## More information

- [Stop calling everything "Nix"](https://haskellforall.com/2022/08/stop-calling-everything-nix)
- [Zero to Nix](https://zero-to-nix.com)
- [nix.dev](https://nix.dev)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world)
