# About coding agents and direnv

Coding agents (Claude Code, Codex, opencode, pi, amp) do much of the work in these projects,
so they need the same environment a person gets in a terminal. Two things make that harder
than it sounds: how the agents are installed, and how a project's environment reaches their
tool calls.

## Installed by Nix, updated by themselves

Most of the agents release almost daily, and T3 Code updates them in place. An updater can't
write into `/nix/store`, so an agent packaged in Nix either goes stale or ends up with a
second copy beside the Nix one. So `home/agents.nix` treats them differently from other tools.
On each switch it checks that each agent is installed and, if one isn't, runs that agent's own
installer: Claude Code's and Codex's native installers, npm for opencode and pi. After that,
the agents update themselves. amp is the exception and still comes from Nix.

Nix still owns everything around them: their settings, hooks and plugins. Claude Code's
home-manager module is used with `package = null`, so it manages the config without installing
the binary. The installers get an explicit PATH, because otherwise Codex's installer tries to
edit `~/.zprofile`, which Nix owns.

## Getting a project's environment into tool calls

A project's toolchain comes from its devenv environment, which direnv loads when you `cd` into
the project. But direnv's usual hook runs when a shell draws its prompt, and an agent's tool
call never draws one: it runs `zsh -c` or `bash -c` and exits. So agents ran commands without
the project's toolchain, or with the wrong one. The clearest case was `rustfmt --check`
passing because it ran on stable Rust when the project formats with nightly.

`home/cli.nix` now loads direnv in non-interactive shells as well: from `.zshenv` for zsh,
`BASH_ENV` for bash and `shellInit` for fish. It took four rounds to get right, and each one
shows something about how shells and agents behave.

The first version fork-bombed the Mac. direnv evaluates `.envrc` by running bash, that bash
read `BASH_ENV`, which ran direnv again, and so on until `fork failed: resource temporarily
unavailable`. A `DIRENV_NONINTERACTIVE` marker now tells the inner shells to leave direnv
alone.

Claude Code then undid it. Each of its Bash calls sources a snapshot of a login shell after
`.zshenv` has run, and the snapshot's PATH replaced direnv's. Claude Code does read
`CLAUDE_ENV_FILE` after the snapshot, so a SessionStart hook in `home/agents.nix` adds the
direnv export there, and `.zshenv` skips its own hook when `CLAUDECODE` is set.

Next, Rust builds started failing with `ld: library not found for -liconv`. cargo runs the
linker, which in Nix is a bash wrapper script, from inside each dependency's source directory
under `~/.cargo/registry`. The hook saw a new directory, reloaded direnv there, found no
project, and unloaded the environment along with `NIX_LDFLAGS`. Builds had only passed before
because `target/` still held artifacts from before the switch to Nix. The hooks now do
nothing when `DIRENV_DIR` is set, meaning an environment was already inherited.

Last, `BASH_ENV` pointed at a file in `/nix/store`. Apps keep the environment they were
launched with, so after a switch they still pointed at the old hook. It now points at a fixed
path, `~/.config/direnv/noninteractive.bash`, whose contents change instead.

The result is that an agent in a devenv project gets the project's environment in every tool
call, the same way a person does in a terminal.
