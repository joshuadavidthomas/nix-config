# History

This repo started on Oct 7, 2026, from a plan named "Going all in on Nix". The plan had one
goal: one repo that describes all machines, and a `devenv.nix` in each project. It had five
phases, each with a test for "done". This page tells how each phase went, and where the plan
was wrong. For the current status, see the [roadmap](../roadmap.md).

## Before Nix

mise managed the tools, a bootstrap task and the dotfiles. A private repo synced the dotfiles.
chezmoi and yadm came before mise. Some problems from that time:

- GUI apps did not get the shell's PATH, so Ghostty could not find fish.
- Neovim had a fixed path to fish.
- Two machines with different mise versions could not read each other's sync data.

## Phases 0 and 1: NixOS-WSL and the repo

The work started on the work laptop, with NixOS as a second WSL distribution. This was safe:
nothing else changed, and one command removes NixOS again.

The first commit added the WSL host and the shared home-manager configuration. The WSL host
has three settings for Windows interop:

- `wsl.interop.register`, so that Windows `.exe` files run
- `nix-ld`, so that the VS Code server runs
- SSH and git signing through the Windows programs of 1Password

Nobody has applied the WSL host since the Mac work changed `home/`. The
[roadmap](../roadmap.md#wsl) lists the work that it needs.

## Phase 3: the Mac

In the plan, the Mac came fourth. In practice, it came second. The general design of the plan
stayed: Determinate Nix, nix-darwin for the system and Homebrew, and the shared home-manager
configuration. Many details changed:

| The plan | What happened |
| --- | --- |
| A host named `mac-mini` | `darwinConfigurations.mac`, for all Apple Silicon Macs. With a name for one machine, each new Mac needs a change to the repo. |
| Install Homebrew first | nix-homebrew installs Homebrew. Its Homebrew version was older than the installed one, so the repo pins a newer version. |
| Run `chsh` after the switch | With `users.knownUsers` and the existing user ID, nix-darwin sets the login shell. The plan said that it cannot. |
| Remove mise slowly | All of mise went at once. |
| sops only on the homelab | sops on all machines, in activation steps. See [About secrets](secrets.md). |
| `sudo nix run …` for the first switch | It needs `sudo -H`. Without `-H`, Nix uses the cache of `root` and downloads all inputs again. |

Most problems in the first switch came from parts of the old setup:

- The old terminal configuration started the Homebrew fish. That fish did not have the
  nix-darwin paths, so `darwin-rebuild` was not found.
- Old fish configuration put `~/.local/bin` before Nix on PATH. That directory had old copies
  of tools.
- mise had supplied Python. Without it, starship used the slow Apple Python and timed out.
- An old `.bak` file stopped home-manager.

Each fix went into the configuration. Additions to PATH now go at the end. Homebrew comes
after Nix. Nix supplies Python.

Homebrew caused more problems:

- After each major Xcode update, Homebrew does not run until you accept the license again. The
  configuration now accepts it before the Homebrew step.
- Homebrew refused formulae from third-party taps. The configuration now marks its taps as
  trusted.
- When Homebrew adopted the running 1Password, 1Password quit.
- A rollback to a generation without the 1Password cask removed 1Password. The setting stays.

Three warnings showed on each build. Each had a cause and got a fix:

- atuin came from the atuin flake. It now comes from an override in `pkgs/`.
- A man page cache option has no effect on macOS. The configuration turns it off.
- The home-manager man page caused a warning. The configuration turns it off.

Some tools were not in nixpkgs, or nixpkgs had older versions. A newer atuin had already
migrated the history database. llm needed newer Python libraries than nixpkgs had, so uv2nix
builds it from a lock file. This is how `pkgs/` and the overlay started. See
[About the design](design.md).

Secrets took the most time. In the final design, 1Password holds one sops key, and sops holds
all other secrets. On the way, three facts came out. Activation steps do not get your PATH.
`op whoami` does not ask you to unlock 1Password. And the licensed fonts had to come out of the
git history before the repo became public. The bootstrap from this work sets up a new Mac with
one command.

## Phase 2: devenv

devenv came after the Mac, in one project (dashtext). The environment was simple to make. Two
lessons apply to all projects:

- For an `env` variable on one platform, use `lib.optionalAttrs`, not `lib.mkIf`.
- On macOS, the Nix clang uses `DYLD_LIBRARY_PATH`. The Apple compiler ignores it.

A build on the Mac also found an app bug that the Linux CI did not find.

The bigger problem was the agents. They run commands without a prompt, so direnv did not load
the environment for them. The fix took four attempts. One attempt used all the processes on
the Mac. See [About coding agents and direnv](agents.md).

CI also moved to devenv. It is slower than with mise, even with a cache for the Nix store.

## Phase 4: the homelab

The first box went in on Oct 8. nixos-anywhere installed it from the Mac. It joined Tailscale,
and colmena deploys to it. Each step needed a change to the plan:

- The plan said to set a password on the installer and connect with SSH. But SSH tried the
  eleven 1Password keys first. sshd stopped after six, and after more failures it blocked the
  Mac for some minutes. The fix was `IdentityAgent=none` in the install command.
- `PubkeyAuthentication=no` made it worse. nixos-anywhere needs a temporary key of its own for
  the rest of the install.
- After the install, the box had a different IP address.
- The first colmena deploy built a different system from the installed one. The hive did not
  have a module that `nixosSystem` adds.

See [About the homelab](homelab.md).

## What stayed the same

The general design of the plan stayed:

- one repo
- a shared home-manager configuration
- a host file for each type of machine
- devenv in each project
- the Mac as the controller of the homelab

The commands and assumptions in the plan changed. Nobody had run them before the plan was
written.

Most problems got a fix after someone looked at what the machine actually did. Several had a
different cause than they first seemed to have.
