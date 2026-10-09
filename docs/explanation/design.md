# About the design

Before this repo, mise managed the tools, the dotfiles and a bootstrap task. chezmoi and yadm
came before mise. Each tool managed part of a machine. This repo describes all of each
machine. The decisions below keep it that way.

## Nix owns the configuration

All settings are in Nix. If home-manager or nix-darwin has a module for a tool, the settings
use that module. If not, the repo contains the file, and Nix installs it. There are no links
from the system back into the repo, and no files to edit in place.

There are two exceptions. Codex writes its own `config.toml`, because the app records trusted
projects in it. The Neovim configuration is in its own repo, and the switch clones it.

A warning that shows on every switch hides new warnings. So each warning gets a fix.

## One file selects the versions

`overlay.nix` selects the source of each package. The flake exports it as
`overlays.default`, so devenv projects can use it too.

- Command-line tools come from `nixpkgs-unstable`. Nothing depends on them, so a newer version
  is safe.
- Runtimes and libraries (Python, Node, Go, ffmpeg) come from the release branch. A different
  version of one of these makes Nix rebuild all the packages that depend on it.

If nixpkgs does not have a package, or has an old version, the repo defines it in `pkgs/` and
adds it through the overlay. The repo does not use the flakes of other projects for packages.
Each such flake brings its own nixpkgs. The atuin flake brought a deprecation warning.
[Geoffrey Huntley's post on overlays](https://ghuntley.com/nix/) describes this approach.

## Homebrew for apps

Apps from Nix do not work well with Spotlight, the Dock and app updaters. So Homebrew installs
the apps, and Nix installs the command-line tools.

- nix-homebrew installs Homebrew, so a new Mac needs only Nix.
- Homebrew comes after Nix on PATH. A Homebrew program cannot hide a Nix program.
- `cleanup = "uninstall"` removes each app that the configuration does not declare. Because of
  this, a rollback can remove an app.

## Coding agents update themselves

Claude Code, Codex, opencode and pi have new releases almost every day. T3 Code updates them.
An updater cannot write to `/nix/store`. So `home/agents.nix` installs each agent with the
agent's own installer, and only if the agent is missing. Nix still controls their settings
and hooks. See [About coding agents and direnv](agents.md).

## One configuration for each type of machine

All Apple Silicon Macs use `darwinConfigurations.mac`. The configuration does not use the
hostname, so a new Mac needs no change to the repo. The homelab uses one shared module, and
a small directory for each box.

## Work settings stay in the work host

The work email, proxies and certificates are in `hosts/work-wsl`. `home/` has only the
settings that are the same on all machines.

## 1Password holds the keys

The SSH keys and the git signing key are in 1Password. One age key, also in 1Password,
decrypts all other secrets. No secret goes into `/nix/store`, which all users can read. This
is why the repo can be public. See [About secrets](secrets.md).

## Good practice

- Record a change before each switch. Then the history shows each change to the system.
- Before you guess what an option does, look at its value in `nix repl`.
- Do not change `stateVersion`. It keeps data formats compatible. It is not the release
  number.
- When something fails, look at what the machine does before you decide on a cause. Run the
  command, read the log, or read the source of the tool. Many problems in this repo had a
  different cause than they first seemed to have.
