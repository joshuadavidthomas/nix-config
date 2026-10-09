# Going all in on Nix

One repo, this one, describes every machine I use, and each project carries its own
`devenv.nix`. This started on Oct 7, 2026 as a roadmap written before any of it existed. This
is that roadmap rewritten to match what actually got built, along with the problems hit on
the way and how each one was solved.

The repo is applied three ways: `rebuild` (nix-darwin) on a Mac, `colmena` from the Mac to the
homelab, and `nixos-rebuild` inside WSL. Every machine then runs the same project
environments.

## Where things stand

| Phase | Where | What you get | Status |
| --- | --- | --- | --- |
| 0 | Work laptop (WSL2) | NixOS-WSL beside the old distro, flakes on | Done |
| 1 | Work laptop | This repo, a NixOS-WSL host, the shared home-manager config | Done, but WSL hasn't been rebuilt since the Mac work reshaped `home/` ([open items](#still-open)) |
| 2 | Projects | `devenv.nix` replaces `mise.toml`, setup scripts and docker-compose | Piloting in one project (dashtext); other projects still have `mise.toml` |
| 3 | Mac | Determinate Nix and nix-darwin, reusing the same home-manager config | Done, for any Apple Silicon Mac, with a one-command bootstrap |
| 4 | Homelab | NixOS boxes from one shared module, installed and deployed from the Mac | `lab-1` is up; two more boxes to go ([homelab.md](homelab.md)) |

## Principles

These came out of the work. Most were decided after doing it the other way first.

- **Nix owns the config.** Use a tool's native home-manager or nix-darwin options first. When
  no module exists, ship the file from this repo through Nix. No out-of-store symlinks or
  edit-in-place files.
- **Fix warnings; don't live with them.** A warning on every switch hides the one that
  matters. Each one so far had a real cause (see [Problems we hit](#problems-we-hit)).
- **One place chooses versions.** `overlay.nix` (exported as `overlays.default`) decides
  where every package comes from. Standalone CLI tools come from `nixpkgs-unstable`;
  runtimes and libraries stay on the release branch, because replacing them rebuilds
  everything that depends on them. Packages nixpkgs lacks, or has too old, are written in
  `pkgs/` and applied through the overlay, not pulled from upstream flakes.
- **GUI apps in Homebrew, CLI in Nix.** Homebrew sits after every Nix path on PATH, so it can
  never shadow a Nix tool. `cleanup = "uninstall"` removes anything not declared.
- **Coding agents update themselves.** Claude Code, Codex, opencode and pi release almost
  daily, and T3 Code updates them in place, which can't work against a read-only
  `/nix/store`. Nix only makes sure they're installed (`home/agents.nix`), and owns their
  config.
- **1Password is the root of trust.** SSH keys and git signing go through its agent. One sops
  age key, stored in 1Password, decrypts everything else in `secrets/`. Nothing secret enters
  `/nix/store`, which is world-readable, so this repo can be public.
- **One configuration per kind of machine, not per hostname.** Every Apple Silicon Mac is
  `mac`. A new Mac needs no edits to the repo.
- **Work stays in the work host.** Work email, proxies and certificates live in
  `hosts/work-wsl`, never in `home/`.

## Repo layout

```text
.
├── flake.nix              # inputs, and one output per kind of machine
├── flake.lock             # the pin; commit it
├── overlay.nix            # where every package version comes from
├── pkgs/                  # packages nixpkgs lacks or has too old (atuin, cf, lisette, llm)
├── home/                  # home-manager, shared by every machine
│   ├── josh.nix           # entry point: packages, PATH, shells
│   ├── agents.nix         # coding agents and their hooks
│   ├── cli.nix            # atuin, bat, direnv, eza, fzf, tmux, …
│   ├── fish.nix, git.nix, neovim.nix
│   ├── nix.nix            # gh's token for flake fetches; clones ~/.nix-config
│   └── secrets.nix        # fetches the age key from 1Password
├── hosts/
│   ├── mac/               # nix-darwin for any Apple Silicon Mac, plus Mac-only home config
│   ├── work-wsl/          # NixOS-WSL
│   └── lab-1/             # a homelab box: hostname, disk layout, generated hardware config
├── modules/server.nix     # everything the homelab boxes share
├── secrets/               # sops-encrypted; recipients in .sops.yaml
└── bootstrap.sh           # fresh Mac to configured, in one command
```

## The layers called "Nix"

"Nix" names about ten separate things, and most confusion comes from mixing them up. When a
doc or blog post says "Nix", work out which layer it means first.

| Layer | What it is | Where you touch it |
| --- | --- | --- |
| Nix language | A lazy, pure expression language. Every config is one big expression that evaluates to data. | Every `.nix` file |
| Nix tool + store | Builds *derivations* (build recipes) into immutable `/nix/store/<hash>-name` paths. Same inputs, same path, so binaries come from a cache instead of being rebuilt. | `nix build`, `nix run`, garbage collection |
| nixpkgs | The package definitions plus all the NixOS modules. Branches are the release channels (`nixos-26.05`, `nixpkgs-unstable`). | `pkgs.ripgrep`, [search.nixos.org](https://search.nixos.org) |
| Flakes | The entry point: `flake.nix` declares *inputs* (pinned in `flake.lock`) and *outputs* (machines, shells, packages). | This repo |
| Module system | Merges many small files into one typed tree of options. NixOS, nix-darwin, home-manager and devenv all use it. | `{ config, pkgs, ... }: { … }` |
| NixOS | A Linux distro whose entire system is one module config. | Homelab, NixOS-WSL |
| nix-darwin | The same idea for macOS: system settings, launchd services, Homebrew. | The Mac |
| home-manager | User-level config: CLI tools, dotfiles, shell, git. Runs on any of the above. | Every machine |
| devenv | Per-project dev environments (languages, services, processes, hooks), also on the module system. | Each project |
| Determinate Nix | A Nix distribution with flakes on by default and better macOS behavior. | The Mac's installer |

**Generations make rollback cheap.** Every switch builds a complete new system in the store,
then flips one symlink to it. The old one stays until garbage collection, so rolling back is
instant. It's also why the store grows.

**There are two CLIs.** The old one is `nix-env`, `nix-build`, `nix-shell` and channels. The
new one is `nix build`, `nix run`, `nix develop` plus flakes. This repo uses only the new
one; the old one still turns up in older blog posts and in NixOS-WSL's first boot.

## Just enough Nix to read configs

About ten constructs cover nearly every config here. Think of it as JSON with functions, local
bindings and lazy evaluation.

```nix
# Attribute set (a dict). Dotted keys nest:
{ programs.git.enable = true; }        # same as { programs = { git = { enable = true; }; }; }

# List: space-separated, no commas
[ pkgs.ripgrep pkgs.fd pkgs.jq ]

# let … in: local bindings
let user = "josh"; in { users.users.${user}.isNormalUser = true; }

# Functions take one argument; `arg: body`. Modules take an attribute set:
{ config, pkgs, lib, ... }: { environment.systemPackages = [ pkgs.htop ]; }

# Strings, interpolation, multi-line strings (indentation stripped)
"hello ${user}"
''
  echo "multi-line"
''

# inherit: shorthand for `user = user;`
{ inherit user; }

# with: bring a set's names into scope (fine for package lists, avoid elsewhere)
with pkgs; [ ripgrep fd ]

# Paths are a real type, not strings, and get copied into the store
imports = [ ./hardware-configuration.nix ];

# Conditionals and lib helpers
lib.mkIf config.services.tailscale.enable { networking.firewall.trustedInterfaces = [ "tailscale0" ]; }
```

**How modules merge.** Every file is a module: a set, or a function returning one, that sets
options, and `imports` pulls in more. Values from every module merge into one tree: lists
concatenate, sets merge recursively, and two different values for the same scalar option is
an error. `lib.mkDefault` (weaker) and `lib.mkForce` (stronger) settle those conflicts.

**`home.packages` vs `programs.*`.** `home.packages` only puts a binary on PATH.
`programs.<name>.enable` installs the package *and* writes its config and shell integration.
If home-manager has a module for a tool, use it; if you only want the binary, use
`home.packages`. NixOS and nix-darwin have the same split (`environment.systemPackages` vs
`programs.*`).

**Where options are documented.**

- NixOS: [search.nixos.org/options](https://search.nixos.org/options)
- home-manager: [home-manager options search](https://home-manager-options.extranix.com)
- nix-darwin: [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/index.html)
- devenv: [devenv options reference](https://devenv.sh/reference/options/)
- This flake: `nix repl`, then `:lf .`, then tab-complete into
  `nixosConfigurations.lab-1.config.…` to see what anything evaluates to.

When an agent writes Nix, have it explain any construct not on this list, and have it run
`nix flake check` itself. Invented option names are the most common failure, and evaluation
catches them immediately.

## Phase 0: NixOS-WSL on the work laptop

NixOS runs as a second WSL distro beside the old one, so nothing else changes, and
`wsl --unregister NixOS` deletes it in one command.

1. Download `nixos.wsl` from the NixOS-WSL releases, then in PowerShell:
   `wsl --install --from-file nixos.wsl` and `wsl -d NixOS`.
2. The default user is `nixos`. Run `passwd`, then `sudo nix-channel --update` once, because
   the image starts on channels.
3. Turn on flakes in `/etc/nixos/configuration.nix`
   (`nix.settings.experimental-features = [ "nix-command" "flakes" ];`) and switch. That's the
   last edit to `/etc/nixos`; Phase 1 replaces it with this repo.

**Other WSL distros.** All WSL distros share one VM. If another distro (Ubuntu,
`docker-desktop`) is already running a UID-1000 user, NixOS's per-user systemd session can't
start: `Failed to start the systemd user session for 'nixos'`, and exit status 4 at the end of
every `nixos-rebuild switch`. The system config still applies. Start NixOS first
(`wsl --shutdown`, then `wsl -d NixOS`), turn off Docker Desktop's WSL integration for distros
you don't need, and make NixOS the default with `wsl --set-default NixOS`.

**Moving off Ubuntu.** `wsl --export` each distro to a tar first; `wsl --import` restores it
exactly. Then move deliberately: tools into `home.packages` as you reach for them, dotfiles
into home-manager, repos re-cloned. Keys and `.env` files are copied by hand and never go in
this repo. Once a week passes without opening Ubuntu, unregister it.

If downloads fail with certificate errors, the corporate network is inspecting TLS: add the
company root CA with `security.pki.certificateFiles` in `hosts/work-wsl`.

## Phase 1: this repo, starting from WSL

`hosts/work-wsl/default.nix` is the WSL host. A few settings there exist because things broke
without them:

- `wsl.defaultUser = "nixos"`: renaming the WSL user takes extra steps, so it keeps the default.
- `wsl.interop.register = true`: without it, running a Windows `.exe` fails with
  `cannot execute binary file`, which breaks `ssh.exe` and 1Password's signer.
- `programs.nix-ld.enable = true`: VS Code's WSL server and other prebuilt binaries need a
  standard dynamic loader, which NixOS doesn't have.

home-manager runs as a NixOS (or nix-darwin) module, set up once by `homeManagerFor` in
`flake.nix`:

- `useGlobalPkgs` makes it use the system's packages and overlay.
- `backupFileExtension = "bak"` lets it replace existing files like `~/.bashrc`. It refuses
  to overwrite files that already exist, and also stops if an old `.bak` is in the way: move
  that one aside and switch again.

`home/josh.nix` never mentions a username, so the same config becomes `nixos` in WSL and
`josh` on the Mac.

### 1Password, GitHub and SSH

1Password holds the SSH keys, so no machine runs `ssh-keygen` or its own agent. What differs
per OS goes in the host files:

- **Shared (`home/git.nix`):** git and jj identity, and signing with the 1Password
  "github.com" key. `gh` handles git over HTTPS. Each host only sets its email and
  `signing.signer`.
- **WSL:** SSH goes through Windows' `ssh.exe`, which talks to the 1Password agent on Windows
  (`core.sshCommand = "ssh.exe"`, with `ssh` and `ssh-add` aliased to the `.exe`s). Since
  `ssh.exe` reads `%USERPROFILE%\.ssh\config`, SSH config for WSL lives on the Windows side.
  `BROWSER` is `wsl-open`, because nixpkgs dropped `wslview`.
- **Mac:** `programs.ssh` sets `IdentityAgent` to 1Password's socket; git signs with
  `/Applications/1Password.app/Contents/MacOS/op-ssh-sign`.

Things that went wrong or needed care:

- **`gh config set` fails** because home-manager owns `~/.config/gh/config.yml` (read-only).
  Change gh settings in `programs.gh.settings`. `gh auth login` still works, since
  `hosts.yml` isn't managed.
- **Flake fetches hit GitHub's rate limit** (60 anonymous requests an hour). `home/nix.nix`
  writes gh's token to `~/.config/nix/access-tokens.conf` (mode 0600) on each switch, and
  `nix.conf` includes it with `!include`. The token never enters the repo or the store. It
  needs `gh auth login` once per machine.
- **More than six keys in the agent.** sshd gives up after six attempts, and the agent offers
  every key. For hosts with a known key, point SSH at that key's public half with
  `IdentitiesOnly` (see `lab-*` in `hosts/mac/home.nix`).

## Phase 2: devenv for projects

Each project gets a `devenv.nix` that declares its toolchain, services, processes and git
hooks, replacing `mise.toml`, setup scripts and docker-compose. The same file works on the
Mac, the lab boxes, agent sandboxes and CI. A project can reuse this repo's package choices:

```yaml
# devenv.yaml
inputs:
  nix-config:
    url: github:joshuadavidthomas/nix-config
```

```nix
# devenv.nix
{ inputs, ... }: { overlays = [ inputs.nix-config.overlays.default ]; }
```

| Command | Does |
| --- | --- |
| `devenv init` | Scaffolds `devenv.nix`, `devenv.yaml`, `.gitignore` |
| `devenv shell` | Enters the environment (direnv does this on `cd`) |
| `devenv up` | Starts services and processes together |
| `devenv test` | Builds the env, starts services, runs `enterTest`: the CI entry point |
| `devenv update` | Bumps pinned inputs in `devenv.lock` |
| `devenv gc` | Deletes old environments |

| In mise | In devenv |
| --- | --- |
| `[tools] python = "3.13"` | `languages.python.version` |
| `[env]` | `env.NAME = "…"` |
| `[tasks]` | `scripts.<name>.exec` or `tasks."app:<name>".exec` |
| docker-compose Postgres/Redis | `services.postgres`, `services.redis` |
| `.pre-commit-config.yaml` | `git-hooks.hooks.*` |

### Agents need the environment too

direnv's usual hook only fires when a shell draws a prompt. Agent tool calls, editor tasks and
`fish -c` never draw one, so they ran without the project's toolchain, sometimes with the wrong
one: `rustfmt --check` passed against stable when the project needs nightly. `home/cli.nix`
now loads direnv in non-interactive shells too (zsh `.zshenv`, bash `BASH_ENV`, fish
`shellInit`). Getting that right took four fixes:

1. **Fork bomb.** direnv evaluates `.envrc` in bash, and that bash read `BASH_ENV` again,
   recursively, until `fork failed: resource temporarily unavailable`. A
   `DIRENV_NONINTERACTIVE` marker stops the recursion.
2. **Claude Code replaced the PATH.** Each Bash call sources a login-shell snapshot after
   `.zshenv`, undoing direnv's PATH. A SessionStart hook in `home/agents.nix` adds the direnv
   export to `CLAUDE_ENV_FILE`, which runs after the snapshot.
3. **`ld: library not found for -liconv` in cargo builds.** cargo runs the linker, a bash
   script, from each crate's directory, and the hook reloaded direnv there, unloading
   `NIX_LDFLAGS`. The hook now does nothing when `DIRENV_DIR` is already set. Earlier builds
   only passed because `target/` held artifacts from the mise era.
4. **Apps kept an old hook.** `BASH_ENV` pointed into `/nix/store`, and apps keep the
   `BASH_ENV` they launched with. It now points at the fixed
   `~/.config/direnv/noninteractive.bash`.

### What else came up in the pilot

- **`env.X was accessed but has no value defined`** came from `lib.mkIf` on an attribute of
  `env`. Use `// lib.optionalAttrs isLinux { … }` for platform-specific variables instead.
- **On macOS, Nix's clang honors `DYLD_LIBRARY_PATH`** where Apple's SIP-protected `cc` strips
  it. A tool that sets it can crash the compiler (`dyld: Symbol not found`). Unset it around
  the call.
- **The Mac build caught a bug Linux-only CI never ran into.** Expect the first devenv run on a
  second platform to find real bugs.
- **CI on devenv is slower** than mise plus a rustup cache, even with
  `nix-community/cache-nix-action`. Release builds stay off Nix, because Nix-built binaries
  reference `/nix/store`.

**Done when:** one real project runs entirely from `devenv up` and passes `devenv test` locally
and in CI. Leave `mise.toml` in a project until devenv has been the daily driver there for a
week or two.

## Phase 3: the Mac

A fresh Mac needs one command (see the [README](../README.md)). `bootstrap.sh` installs
Determinate Nix, switches straight from GitHub (installing Homebrew, every app, 1Password
included, and every tool), waits for 1Password to be signed in, then switches again so
secrets fall into place. After that, `rebuild` applies `~/.nix-config`.

Where this ended up different from the roadmap:

| The roadmap said | What's built, and why |
| --- | --- |
| A host named `mac-mini` | `darwinConfigurations.mac`, for any Apple Silicon Mac. A new Mac shouldn't need a repo edit. Intel Macs are refused; several packages no longer build there. |
| Install Homebrew by hand first | nix-homebrew installs it. Its own pin of brew trailed the installed version and would have downgraded it, so `brew-src` is pinned in `flake.nix`. |
| `chsh` to fish after the switch | `users.knownUsers = [ "josh" ]` with `uid = 501` lets nix-darwin set the login shell itself. On an existing account it only changes the shell. |
| Move off mise gradually | Removed in one go; the tools came over to `home.packages` and `pkgs/`. |
| sops only for the homelab | sops on every machine, run from home-manager activation steps rather than sops-nix (below). |
| `sudo nix run …#darwin-rebuild -- switch` | Needs `sudo -H`. Plain `sudo` keeps your `$HOME`, Nix falls back to root's, and root re-downloads every input into its own cache. |

**Done when:** a fresh `rebuild` is a no-op, the shell and tools match the other machines, and
you've rolled back once.

### Problems on the Mac

- **The Xcode license.** Every major Xcode update needs the license accepted again, and
  Homebrew refuses to run until it is, aborting the switch. A preActivation script in
  `hosts/mac/default.nix` accepts it before the Homebrew step.
- **`darwin-rebuild: command not found` after the first switch.** The old terminal config
  started Homebrew's fish, which never gets `/run/current-system/sw/bin` on PATH. The
  terminals now use the login shell, which is Nix's fish.
- **Old copies shadowing Nix.** Leftover fish config put `~/.local/bin`, full of stale
  installer copies, ahead of Nix. PATH additions are now append-only, and Homebrew goes after
  Nix with `environment.systemPath = lib.mkAfter [ … ]`.
- **starship timing out on `/usr/bin/python3`.** Removing mise removed its Python, leaving
  Apple's slow stub. Nix's `python314` is in `home.packages`.
- **Homebrew refusing untrusted taps.** Formulae from third-party taps fail with
  `Refusing to load formula … from untrusted tap`. Taps declared in `hosts/mac/default.nix`
  are marked `trusted = true`, since declaring them already means trusting them. A renamed
  formula (`obsidian-cli` became `notesmd-cli`) needed its new name.
- **Rollback can uninstall apps.** With `cleanup = "uninstall"`, rolling back to a
  generation from before a cask was added removes the app, 1Password included. Rolling
  forward reinstalls it. Kept on purpose.
- **Overwriting a running app.** Adopting the already-running 1Password with
  `brew install --cask --adopt` made it quit. Fresh Macs don't hit this.
- **Warnings on every build**, each fixed rather than ignored:
  - `stdenv.isDarwin is deprecated`: atuin came from atuin's own flake. It's now
    `pkgs/atuin.nix`, an override of nixpkgs' recipe.
  - `programs.man.generateCaches has no effect`: turned off on macOS.
  - `options.json … without a proper context`: home-manager's man page;
    `manual.manpages.enable = false`.

### Packages nixpkgs didn't have

- **atuin 18.23.0.** nixpkgs had 18.21.0, but the history database was already migrated by
  18.23. Some of its tests spawn a pty shell, which can't start in the build sandbox, so
  `checkFlags` skips them.
- **llm 0.36 with plugins.** It needs newer openai and httpx than nixpkgs has, so it's built
  with uv2nix from a `uv.lock` (`pkgs/llm/`), pinned to the versions that already worked.
- **cf** is the published npm package (`buildNpmPackage`), since upstream is a pnpm monorepo.
  **lisette** uses the release binaries.

### Secrets

- **The design.** 1Password is the root. One sops age key is stored in 1Password as the
  document "nix-config sops age key". The first switch after 1Password is signed in fetches
  it to `~/.config/sops/age/keys.txt` (`home/secrets.nix`), and sops decrypts the rest of
  `secrets/` from there. To edit secrets, run `sops secrets/secrets.yaml`.
- **Why not sops-nix?** Its home-manager module decrypts in the background through launchd
  or systemd. That gives no guarantee the secrets are ready before the steps that need them
  (logging atuin in), and systemd user services are unreliable on WSL. Plain `sops` inside
  activation steps runs in order and decrypts in memory.
- **Activation doesn't see your PATH,** so `op` is called at `/usr/local/bin/op`. That's
  where `programs._1password` installs it, and the only place 1Password's CLI integration
  accepts.
- **`op whoami` never prompts.** Waiting on it with 1Password locked waits forever. Asking
  for the document directly triggers the Touch ID prompt, and `bootstrap.sh` waits on
  `op vault list`.
- **Licensed fonts.** MonoLisa is committed only as sops-encrypted files and decrypted
  straight into `~/Library/Fonts`, because macOS ignores symlinked fonts. Before the repo went
  public, earlier plaintext copies were removed from history with `git filter-repo`.
- **atuin logs itself in** from sops values when `atuin status` says it isn't. An account
  created through GitHub sign-in has no password, so it needed one added before the CLI could
  log in.

## Phase 4: the homelab

The installing and deploying steps are in [homelab.md](homelab.md). In short: `lab-1` was
installed from the Mac with nixos-anywhere, joined Tailscale, and is deployed with
`colmena apply`. All builds run on the box, so the Mac needs no Linux builder.

What went differently from the roadmap:

- **The installer can't be reached the way the roadmap assumed.** The roadmap's plan was to
  set a password on the installer and SSH in. 1Password's agent offers all eleven keys
  first, and sshd disconnects after six, then blocks the Mac for minutes after repeated
  failures (`Connection reset by peer`). The install command now passes
  `--ssh-option IdentityAgent=none`.
- **`PubkeyAuthentication=no` is a trap.** nixos-anywhere logs in once with the password, puts
  its own temporary key on the installer, and switches to root with it. With key logins off,
  it asks for root's password instead, which doesn't exist.
- **The box came back on a different IP** after the install, so the next step needs
  Tailscale or the router's client list rather than the old address.
- **colmena built a slightly different system** than nixos-anywhere installed: the box
  called itself `26.05pre-git`. colmena skips modules nixpkgs adds inside `nixosSystem`. The
  hive now imports each box's module list from `nixosConfigurations` and sets the version
  label, so both build the identical system.

Still ahead, roughly in order:

- **Boxes two and three:** a name in `labs`, a copy of `hosts/lab-1`, and one install command
  each.
- **Secrets on the boxes:** sops with age keys derived from each box's SSH host key
  (`ssh-to-age`), starting with a Tailscale auth key so `tailscale up` is declarative.
- **A binary cache:** harmonia on one box, trusted by the others, so each thing builds once.
- **A build fleet:** the boxes as each other's remote builders (and the Mac's, which is how
  it would build Linux systems). The builder key belongs to the Nix daemon, not you, so it
  comes from sops, and builders' host keys need pinning so daemon-to-daemon SSH has no
  prompt to answer. Add machines when builds queue, not before.
- **Unattended upgrades** with `system.autoUpgrade`, once updating `flake.lock` is routine.

**Done when:** all three boxes are reachable as `lab-1`…`lab-3` over Tailscale, one
`colmena apply` updates them all, and you've rolled one back from the boot menu.

## Problems we hit

A quick lookup by symptom. The phase sections above have the story behind each one.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `path … does not exist` for a file you just created | Flakes only see files git knows about. (Determinate Nix on the Mac also picks up untracked files; upstream Nix on WSL may not.) | Run any `jj` command, which records new files |
| `git commit` made an empty commit | The repo is jj; it had already recorded the change | `jj describe -m …` and `jj new`; `jj abandon` the empty one |
| `Too many authentication failures`, or `Connection reset by peer` while ping works | 1Password offers more keys than sshd allows; sshd then blocks the address for minutes | Name the key with `IdentitiesOnly`, or `IdentityAgent=none` for password logins; `sudo systemctl restart sshd` on the box clears the block |
| A blank line in a pasted multi-line command | The shell ends the command there and drops the remaining flags | Paste long commands as one line |
| `$HOME … is not owned by you` from `sudo nix …` | `sudo` keeps your `$HOME` on macOS | `sudo -H` |
| `You have not agreed to the Xcode license` aborts a switch | Xcode was upgraded | Handled by the preActivation script; switch again |
| home-manager stops before switching, naming a `.bak` file | An old backup is in the way of a new one | Move the old `.bak` aside |
| A tool resolves to a stale copy | `~/.local/bin` or Homebrew ahead of Nix on PATH | Keep them after Nix; delete leftover installer copies |
| `Refusing to load formula … from untrusted tap` | Homebrew distrusts third-party taps | Declare the tap with `trusted = true` |
| An agent's tool calls lack the project toolchain | direnv only hooks interactive prompts | The non-interactive hooks in `home/cli.nix` (Phase 2) |
| `fork failed: resource temporarily unavailable` | A `BASH_ENV` hook running inside direnv's own bash | The `DIRENV_NONINTERACTIVE` guard |
| `ld: library not found for -liconv` in a direnv project | A hook reloaded direnv inside cargo's linker and dropped `NIX_LDFLAGS` | Hooks skip shells where `DIRENV_DIR` is set |
| Flake fetches fail on GitHub's rate limit | Anonymous API limit | gh's token in `~/.config/nix/access-tokens.conf` (Phase 1) |
| `cannot execute binary file` running a Windows `.exe` in WSL | WSL's interop handler isn't registered | `wsl.interop.register = true` |
| `Failed to start the systemd user session` in WSL | Another distro holds the UID-1000 session | Start NixOS first (Phase 0) |
| A downloaded binary won't run on NixOS (`No such file or directory`) | No standard dynamic loader | `programs.nix-ld.enable = true` |
| A pip/uv wheel can't find a `.so` | Prebuilt wheels expect `/usr/lib` | In devenv, add the library to `packages`; outside it on NixOS, `nix-ld` |
| A deployed lab box calls itself `26.05pre-git` | The colmena hive missed modules `nixosSystem` adds | Fixed in `flake.nix`; don't give the hive its own module list |
| Disk fills up | Every generation and dev shell is kept | `nix.gc.automatic` on the boxes, `devenv gc`, `nix store gc` |
| An update broke something | `nix flake update` bumped everything at once | Restore `flake.lock`, switch, then update inputs one at a time (`nix flake update nixpkgs`) |
| `infinite recursion encountered` | A module reads `config` to decide what to define, often inside `imports` | Move the condition into `lib.mkIf` on the value |
| A wall of evaluation trace | Nix prints the whole call stack | Read the bottom-most `error:` first, then the frames nearest your files; `--show-trace` only if needed |

**Habits that pay off**

- Record a change (`jj describe`) before every switch. History is the change log.
- Use `nix repl` with `:lf .` to see what an option evaluates to before guessing.
- Use `nvd diff` (or `nix store diff-closures`) to see what a switch changes.
- Keep `stateVersion` values at their install-time setting. They protect data formats; they
  aren't the release you're on.
- When something doesn't work, check the actual state (run it, read the log) before deciding
  why. Several of the problems above looked like something else at first.

## Still open

- **WSL hasn't been rebuilt** since the Mac work reshaped `home/`. Before it will switch
  cleanly:
  - it needs `secrets.op` pointed at Windows' `op.exe`, or another way to get the age key;
  - it will build atuin, cf, lisette and llm from source;
  - the git signer should be checked: the repo uses `op-ssh-sign.exe`, while the roadmap
    recommended `op-ssh-sign-wsl.exe`, because the plain one can't read the Linux temp-file
    path git passes it.
- **Known hosts:** pin host keys (GitHub, Forgejo, the lab boxes) in a shared module, so no
  machine sees a first-connection prompt. The roadmap's `modules/known-hosts.nix` hasn't been
  written.
- **More of the Mac in Nix:** apps installed outside Homebrew, macOS defaults (Finder,
  trackpad, appearance), login items, and the remaining tokens (Claude, gh, Todoist) via sops.
- **Maintenance:** a CI job that opens `flake.lock` update PRs, and garbage collection on the
  Mac.
- **Devenv beyond the pilot:** the projects that still have `mise.toml`.

## Commands

| Task | Command |
| --- | --- |
| Apply the Mac | `rebuild` (`rebuild --rollback` to undo) |
| Apply WSL | `sudo nixos-rebuild switch --flake .#work-wsl` |
| Deploy the homelab | `colmena apply` (`--on lab-2` for one box) |
| Run a tool once | `nix run nixpkgs#<pkg>` |
| Temporary shell with tools | `nix shell nixpkgs#a nixpkgs#b` |
| Find a package | `nix search nixpkgs <term>` |
| Update all inputs / one | `nix flake update` / `nix flake update nixpkgs` |
| Check the flake | `nix flake check` |
| Inspect the config | `nix repl`, then `:lf .` |
| Edit secrets | `sops secrets/secrets.yaml` |
| Clean up | `nix store gc`, `devenv gc` |

## Further reading

- [Stop calling everything "Nix"](https://haskellforall.com/2022/08/stop-calling-everything-nix): the layers, explained
- [Zero to Nix](https://zero-to-nix.com): a flakes-first beginner path
- [nix.dev](https://nix.dev): official tutorials, including the language tour
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world): the best single walkthrough of a flake-based NixOS + home-manager config
- [Geoffrey Huntley: fix everything with a Nix overlay](https://ghuntley.com/nix/): the reason `overlay.nix` exists
- [nix-darwin](https://github.com/nix-darwin/nix-darwin), [devenv](https://devenv.sh), [NixOS-WSL](https://nix-community.github.io/NixOS-WSL/install.html)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md), [Colmena](https://colmena.cli.rs/unstable/)
