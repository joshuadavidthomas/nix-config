# About this repo's design

This repo replaced a setup built on mise: its tool versions, its dotfile tracking and a
bootstrap task, synced through a private dotfiles repo. Earlier still, there were chezmoi and
yadm. Each of those managed some of a machine. The point of moving to Nix was to have one
place that describes all of it, so most of the decisions below come back to keeping that true.
Most of them were made after trying it the other way first.

## Nix owns the config

Every setting is expressed in Nix: a tool's home-manager or nix-darwin options when a module
exists, and otherwise the file itself, shipped from this repo through Nix. There are no
out-of-store symlinks pointing back into a checkout, and no files left to be edited in place.
The exceptions are deliberate and few: Codex's `config.toml`, because the app records trusted
projects in it, and the Neovim config, which lives in its own repo and is cloned rather than
generated.

Warnings get the same treatment. A warning that prints on every switch hides the one that
matters, and each one so far turned out to have a real cause with a real fix.

## One place chooses versions

`overlay.nix` decides where every package comes from, and the flake exports it as
`overlays.default`, so projects using devenv can share it. Standalone CLI tools come from
`nixpkgs-unstable`, since they're leaf packages and newer is usually better. Runtimes and
libraries (Python, Node, Go, ffmpeg) stay on the release branch, because swapping one out
rebuilds everything that depends on it instead of fetching it from the cache.

When nixpkgs lacks a package or has it too old, the package is written in `pkgs/` and applied
through the overlay. That's the approach in
[Geoffrey Huntley's post on overlays](https://ghuntley.com/nix/): pull the fix into your own
overlay, rather than depending on a project's own flake, which brings its own nixpkgs and its
own warnings. atuin was first pulled from atuin's flake, and it brought a deprecation warning
along with it.

## Homebrew for GUI apps

macOS apps installed from Nix don't integrate well with Spotlight, the Dock or their own
updaters, so GUI apps come from Homebrew casks, and Nix owns everything on the command line.
nix-homebrew installs Homebrew itself, so a fresh Mac needs nothing but Nix. Homebrew sits
after every Nix path on PATH, so it can't shadow a Nix tool, and `cleanup = "uninstall"`
removes anything not declared. The cost of that last one shows up in rollbacks, which can
uninstall an app added later.

## Coding agents update themselves

Claude Code, Codex, opencode and pi release almost daily. T3 Code updates them in place, and
an update can't write into a read-only `/nix/store`, so packaging them in Nix would mean
either stale agents or a second, unmanaged copy. Instead, `home/agents.nix` only checks that
each one is installed and runs its own installer if not. Nix still owns their configuration
and hooks. [About coding agents and direnv](agents.md) covers the rest.

## One configuration per kind of machine

Every Apple Silicon Mac uses `darwinConfigurations.mac`. Nothing in it depends on the
hostname, so a new Mac needs the bootstrap and no repo change. The homelab works the same
way in a different shape: one shared module, plus a small directory per box for what really
differs.

## Work stays in the work host

Work email, proxies and certificates live in `hosts/work-wsl`. `home/` holds only what's the
same everywhere, so personal machines never pick up work settings.

## 1Password at the root

SSH keys and git signing go through 1Password's agent on every machine, and one age key
stored in 1Password unlocks every other secret. Nothing secret enters the world-readable
`/nix/store`, which is what lets the repo be public. [About secrets](secrets.md) explains how.

## Habits that pay off

Record a change before every switch, so the history doubles as a change log. Check what an
option actually evaluates to in `nix repl` before guessing. Leave `stateVersion` values at
their install-time setting; they protect on-disk data formats and have nothing to do with the
release you're on. And when something breaks, look at the actual state (run it, read the log,
read the tool's source) before deciding why. Several problems in this repo's history looked
like something else at first.
