# How the move to Nix went

This repo started on Oct 7, 2026 from a written plan, "Going all in on Nix". The plan described
where this would end up: one repo describing every machine, and a `devenv.nix` in each project.
It split the work into five phases, each ending with a "done when" check. This is how those
phases actually went, and where reality disagreed with the plan. The [roadmap](../roadmap.md)
has the current status.

## Before Nix

Machine setup ran on mise: tool versions, a bootstrap task, and dotfiles tracked in place and
synced through a private repo, after earlier attempts with chezmoi and yadm. The problems from
that period were the kind a single description of the machine avoids. GUI apps launched
without the shell's PATH, so Ghostty couldn't find fish. Neovim had fish's path hard-coded. Two
machines on different mise versions couldn't read each other's sync metadata.

## Phase 0 and 1: NixOS-WSL and the repo

The plan started on the work laptop, with NixOS installed as a second WSL distro, because it's
a safe place to learn: nothing else changes and one command deletes it. The first commit was
the WSL host and the shared home-manager config. The WSL-specific settings are the ones that
were needed to make Windows interop work at all: registering WSL's handler so `.exe` files
run, `nix-ld` so VS Code's server runs, and SSH and git signing routed through 1Password's
Windows binaries.

WSL hasn't been rebuilt since. The Mac work that followed reshaped `home/` around
macOS-specific assumptions, and the [roadmap](../roadmap.md) lists what needs fixing first.

## Phase 3: the Mac

The plan had the Mac second-to-last, but it came next. The plan's outline held: Determinate
Nix underneath, nix-darwin for the system and Homebrew, the shared home-manager config on top.
The details changed a lot.

| The plan said | What happened |
| --- | --- |
| A host named `mac-mini` | `darwinConfigurations.mac`, for any Apple Silicon Mac. Naming the host after one machine meant a new Mac would need a repo edit. |
| Install Homebrew by hand first | nix-homebrew installs it, so a fresh Mac needs only Nix. Its pinned Homebrew was older than the installed one and would have downgraded it, so the pin is overridden. |
| Run `chsh` after the switch | Setting `users.knownUsers` with the existing uid lets nix-darwin set the login shell itself. The plan was wrong that it couldn't. |
| Move off mise gradually | Removed in one go. |
| sops only for the homelab | sops on every machine, called from activation steps; see [About secrets](secrets.md). |
| `sudo nix run …` for the first switch | Needs `sudo -H`. Plain `sudo` keeps your `$HOME`, so Nix falls back to root's and downloads every input again. |

The first switch surfaced a run of problems, and most of them came from the old setup still
being partly in place. The old terminal config started Homebrew's fish, which never gets
nix-darwin's paths, so `darwin-rebuild` seemed to vanish after the switch. Leftover fish config
put `~/.local/bin`, full of stale installer copies, ahead of Nix. Removing mise removed its
Python, and starship started timing out on Apple's slow stub. A stale `.bak` file stopped
home-manager. Each fix became part of the config: PATH additions are append-only, Homebrew goes
after Nix, Python comes from Nix.

Other problems came from Homebrew. Every major Xcode update needs its license accepted again,
and Homebrew refuses to run until it is, so the config now accepts it before the Homebrew step.
Formulae from third-party taps were refused as untrusted, so declared taps are marked trusted.
Adopting the running 1Password into Homebrew made it quit. And with `cleanup = "uninstall"`,
rolling back to a generation from before the 1Password cask existed uninstalled 1Password,
which was kept anyway.

Three warnings printed on every build. Each was tracked down rather than ignored: atuin pulled
from its own flake (now an override in `pkgs/`), a man-page cache option that does nothing on
macOS, and home-manager's own man page.

Several tools weren't in nixpkgs, or not at the versions already in use. atuin's history
database had been migrated by a newer version than nixpkgs had. llm needed newer Python
libraries than nixpkgs carried, so it's built with uv2nix from a lock file pinned to what had
already worked. That's how `pkgs/` and the overlay came about; [About this repo's
design](design.md) explains the version policy.

Secrets took the longest to get right. The design that stuck puts 1Password at the root and
one sops key in 1Password. Getting there meant finding out that activation can't see your
PATH, that `op whoami` never prompts, and that the licensed fonts had to come out of git
history before the repo could go public. The bootstrap that came out of it takes a fresh Mac to
fully configured with one command.

## Phase 2: devenv

devenv came after the Mac, piloted in one project (dashtext). The environment itself was
straightforward. Two lessons were general: a platform-specific `env` variable needs
`lib.optionalAttrs` rather than `lib.mkIf`, and Nix's clang on macOS honors
`DYLD_LIBRARY_PATH` where Apple's compiler doesn't. Building on the Mac also turned up an app
bug that Linux-only CI had never hit.

The harder problem was agents. They run commands without ever drawing a prompt, so direnv
never loaded the project's environment for them. Fixing that took four rounds, including one
that fork-bombed the Mac; [About coding agents and direnv](agents.md) tells it. CI moved to
devenv too, and runs slower than mise did, even with the Nix store cached.

## Phase 4: the homelab

The first box went in on Oct 8. nixos-anywhere installed it from the Mac, it joined Tailscale,
and colmena deploys to it. Each step needed a correction to the plan.

The plan said to set a password on the installer and SSH in. But SSH offered all eleven of
1Password's keys first, sshd gave up after six, and after enough failures it blocked the Mac
for minutes at a time. Turning off key logins entirely made it worse, because nixos-anywhere
relies on a temporary key of its own for the rest of the install. Keeping the 1Password agent
out of that one command (`IdentityAgent=none`) fixed it. The box then came back on a different
IP than the installer had. And the first colmena deploy built a slightly different system from
the one installed, because the hive missed a module nixpkgs adds itself. [About the
homelab](homelab.md) covers the design that came out of it.

## What carried through

The plan's shape held up: one repo, a shared home-manager config, a host file per kind of
machine, devenv per project, and the Mac as the controller for the homelab. Most of what
changed was the plan's specific commands and assumptions, written before any of it had run.
Most of the problems above were solved by checking what the machine was actually doing, and
several turned out to be something other than they first looked like.
