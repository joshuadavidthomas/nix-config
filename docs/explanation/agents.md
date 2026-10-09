# About coding agents and direnv

Coding agents (Claude Code, Codex, opencode, pi, amp) do much of the work in these projects.
They need the same environment as a person in a terminal. Two things make this difficult: how
the agents get installed, and how the project environment gets to their commands.

## How the agents get installed

Most agents have a new release almost every day, and T3 Code updates them. An updater cannot
write to `/nix/store`. If Nix installed the agents, they would become old, or a second copy
would appear next to the Nix copy.

So `home/agents.nix` does not install the agents from Nix. At each switch, it checks each
agent. If an agent is missing, it runs the agent's own installer:

- Claude Code and Codex: their native installers
- opencode and pi: npm

After that, the agents update themselves. amp is an exception and comes from Nix.

Nix still controls the settings, hooks and plugins of the agents. The Claude Code module in
home-manager has `package = null`, so it writes the settings but does not install the program.
The installers get a fixed PATH. Without it, the Codex installer tries to edit `~/.zprofile`,
which Nix controls.

## How the project environment gets to agents

Each project gets its tools from devenv, and direnv loads the environment when you `cd` into
the project. But direnv usually loads only when a shell shows a prompt. An agent runs each
command with `zsh -c` or `bash -c`, and these shells show no prompt. So the agents ran
commands without the project tools, or with the wrong ones. In one project, `rustfmt --check`
passed because it ran with stable Rust, but the project uses nightly.

Now `home/cli.nix` loads direnv in shells without a prompt too:

- zsh: from `.zshenv`
- bash: from `BASH_ENV`
- fish: from `shellInit`

This took four fixes.

### 1. The hook started itself without end

direnv runs `.envrc` in bash. That bash read `BASH_ENV`, which ran direnv again, and so on. The
Mac ran out of processes: `fork failed: resource temporarily unavailable`. Now direnv sets
`DIRENV_NONINTERACTIVE`, and the hook does nothing when it sees that variable.

### 2. Claude Code removed the environment

Before each command, Claude Code loads a saved copy of a login shell. This happens after
`.zshenv`, so the saved PATH replaced the PATH from direnv. Claude Code reads
`CLAUDE_ENV_FILE` after the saved copy. So a SessionStart hook in `home/agents.nix` adds the
direnv export to that file. `.zshenv` skips its own hook when `CLAUDECODE` is set.

### 3. Rust builds lost the linker flags

Builds failed with `ld: library not found for -liconv`. cargo runs the linker from the source
directory of each dependency, in `~/.cargo/registry`. In Nix, the linker is a bash script. The
hook found a new directory and loaded direnv again. No project was there, so direnv removed
the environment, and `NIX_LDFLAGS` with it.

Earlier builds passed only because `target/` had files from mise. Now the hooks do nothing
when `DIRENV_DIR` is set, because then the shell already has an environment.

### 4. Apps kept the old hook

`BASH_ENV` pointed to a file in `/nix/store`. An app keeps the environment from its start, so
after a switch, apps still used the old file. Now `BASH_ENV` points to a fixed path,
`~/.config/direnv/noninteractive.bash`. A switch changes the file, not the path.

## Result

In a devenv project, each agent command gets the project environment, as in a terminal.
