# Troubleshooting

Problems hit so far, by symptom. [How the move to Nix went](../explanation/history.md) has the
story behind most of them.

## Any machine

| Symptom | Cause | Fix |
| --- | --- | --- |
| `path … does not exist` for a file you just created | Flakes only see files git knows about. Determinate Nix on the Mac also sees untracked files; upstream Nix may not. | Run any `jj` command, which records new files |
| `git commit` made an empty commit | The repo is jj, which had already recorded the change | `jj describe -m …` and `jj new`; `jj abandon` the empty commit |
| Flake fetches fail on GitHub's rate limit | Nix is fetching anonymously | `gh auth login`, then switch, so Nix gets gh's token |
| `gh config set` fails with a read-only file | home-manager owns `~/.config/gh/config.yml` | Set it in `programs.gh.settings` |
| home-manager stops before switching, naming a `.bak` file | An old backup is in the way of a new one | Move the old `.bak` aside |
| A tool resolves to a stale copy | `~/.local/bin` or Homebrew is ahead of Nix on PATH | Keep them after Nix; delete leftover installer copies |
| A pasted multi-line command ignores its last flags | A blank line in the paste ended the command | Paste long commands as one line |
| An update broke something | `nix flake update` bumped everything at once | `jj restore --from <change> flake.lock`, apply, then update inputs one at a time |
| Disk fills up | Every generation and dev shell is kept | `nix store gc`, `devenv gc`, `sudo nix-collect-garbage --delete-older-than 30d` |
| `infinite recursion encountered` | A module reads `config` to decide what to define, often inside `imports` | Move the condition into `lib.mkIf` on the value |
| A wall of evaluation trace | Nix prints the whole call stack | Read the bottom-most `error:` first, then the frames nearest your files; add `--show-trace` only if needed |

## Mac

| Symptom | Cause | Fix |
| --- | --- | --- |
| `$HOME … is not owned by you` from `sudo nix …` | `sudo` keeps your `$HOME` on macOS | `sudo -H` |
| `You have not agreed to the Xcode license` aborts a switch | Xcode was upgraded | Switch again; the config accepts it before the Homebrew step |
| `darwin-rebuild: command not found` after the first switch | The terminal started a shell without Nix's paths | `sudo /run/current-system/sw/bin/darwin-rebuild …` once, then a new terminal |
| `Refusing to load formula … from untrusted tap` | Homebrew distrusts third-party taps | Declare the tap with `trusted = true` in `hosts/mac/default.nix` |
| An app disappeared after a rollback | `cleanup = "uninstall"` removes casks the older generation didn't declare | Roll forward, or `rebuild` |
| starship warns that `/usr/bin/python3` timed out | Apple's Python stub is slow | Keep Nix's `python314` in `home.packages` |
| The sops age key isn't fetched | 1Password is locked or its CLI integration is off | Unlock it, turn on Settings > Developer > Integrate with 1Password CLI, switch again |

## WSL

| Symptom | Cause | Fix |
| --- | --- | --- |
| `cannot execute binary file` running a Windows `.exe` | WSL's interop handler isn't registered | `wsl.interop.register = true` |
| `Failed to start the systemd user session`, or switches end in exit status 4 | Another distro holds the UID-1000 session | Start NixOS first; see [Set up NixOS-WSL](../how-to/set-up-nixos-wsl.md#if-other-wsl-distros-are-running) |
| A downloaded binary fails with `No such file or directory` | NixOS has no standard dynamic loader | `programs.nix-ld.enable = true` |
| Certificate errors on downloads | The corporate network inspects TLS | Add the root CA with `security.pki.certificateFiles` |

## devenv and agents

| Symptom | Cause | Fix |
| --- | --- | --- |
| An agent's tool calls lack the project toolchain | direnv only hooks interactive prompts | The non-interactive hooks in `home/cli.nix` |
| `fork failed: resource temporarily unavailable` | A `BASH_ENV` hook ran inside direnv's own bash | The `DIRENV_NONINTERACTIVE` guard in `home/cli.nix` |
| `ld: library not found for -liconv` | A hook reloaded direnv inside cargo's linker | Hooks skip shells where `DIRENV_DIR` is set |
| `The option 'env.X' was accessed but has no value defined` | `lib.mkIf` on an attribute of `env` | `// lib.optionalAttrs cond { … }` |
| The compiler crashes with `dyld: Symbol not found` on macOS | A tool set `DYLD_LIBRARY_PATH`, which Nix's clang honors | Unset it around that tool |
| A pip/uv wheel can't find a `.so` | Prebuilt wheels expect `/usr/lib` | In devenv, add the library to `packages`; on NixOS outside devenv, `nix-ld` |

## Homelab

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Too many authentication failures`, or `Connection reset by peer` while ping works | 1Password offers more keys than sshd allows, and sshd then blocks the address | `sudo systemctl restart sshd` on the box; `IdentityAgent=none` for password logins, `IdentitiesOnly` with `~/.ssh/lab.pub` otherwise |
| nixos-anywhere keeps asking for a `root@…` password | `PubkeyAuthentication=no` blocks its temporary key | Use `--ssh-option IdentityAgent=none` instead |
| The box doesn't answer after the install | It came back on a different IP | Find its MAC in the router's DHCP list or `arp -an` |
| A deployed box calls itself `26.05pre-git` | The colmena hive missed modules `nixosSystem` adds | Fixed in `flake.nix`; the hive imports each box's `nixosConfigurations` modules |
