# Amp orbs

Amp agents can work on this repo in orbs: Debian 12 sandboxes in the cloud. An orb is not one
of the machines. It does not apply this configuration, and it has no secrets.

## What an orb gets

`.agents/setup` runs once for each new orb. Amp saves the result as a snapshot and starts
later orbs from it, for up to 72 hours. The script:

1. Installs Nix for the user, without a daemon.
2. Turns on flakes in `~/.config/nix/nix.conf`.
3. Fetches the inputs, evaluates every configuration and builds the packages in `pkgs/`, so
   `nix flake check` has nothing left to build.
4. Writes notes for agents in the orb to `~/.config/amp/AGENTS.md`. See [Memory](#memory).

Each step skips what is already done. When `flake.lock` or `pkgs/` change, setup builds only
what changed.

`.agents/resume` runs each time an orb starts or wakes. It writes the thread's GitHub token to
`~/.config/nix/access-tokens.conf`, as `home/nix.nix` does on the machines. Setup deletes this
file, so the snapshot has no token.

## Time

| Run | Time |
| --- | --- |
| New orb, empty store | About 2.5 minutes |
| Later runs | About 30 seconds. Nearly all of it is the evaluation of the configurations. |
| `.agents/resume` | Less than 5 seconds |
| `nix flake check`, after setup | About 40 seconds |

Amp stops setup after 20 minutes. Then it saves no snapshot, and each new orb runs setup
again. Do not let setup build a large package from source: on the default orb size (a1.small,
2 CPUs), atuin took more than 22 minutes. See
[When nixpkgs has an older version](changes.md#when-nixpkgs-has-an-older-version).

## Memory

The default orb size, a1.small, has about 3 GB of memory. `nix flake check` uses about 2.7 GB
to evaluate the configurations. If it must also build a package, it can run out of memory.
So setup evaluates and builds in separate steps, and the notes tell agents to do the same. A
larger orb size removes the problem.

## What an orb cannot do

- Apply a configuration. It is not a Mac, NixOS or a lab box.
- Build the Mac configuration. It is `x86_64-linux`.
- Read secrets. It has no opnix token.
- Sign commits. The signing keys are in 1Password.

## Orbs on the lab boxes

An orb from any project can join the tailnet with the tag `orb`, from an Amp secret, and SSH to
the lab boxes as the user `orb`. `modules/nixos/server.nix` makes the user and turns on
Tailscale SSH. The tailnet policy, in the `tailscale-acls` repo, maps the tag to the user.

`orb` has passwordless sudo, like `josh`. It is not a boundary. It keeps agents out of `josh`'s
home and keys, and makes root a step that the journal records:

```sh
journalctl _COMM=sudo
```

A lab box needs the tag `lab` before orbs can reach it.

## Change the setup

Edit `.agents/setup` or `.agents/resume`, then run each one twice in an orb. Push the change to
`main`. New orbs use it.
