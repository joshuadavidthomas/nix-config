# Changes

## Where a change goes

| To add or change | Edit |
| --- | --- |
| A command-line tool or language, on all machines | `home.packages` in `home/default.nix` |
| A tool that is already configured | The file in `home/` that configures it |
| A coding agent, or its settings and hooks | `home/agents.nix` |
| A tool that releases too often to pin, such as cf | The npm installs in `home/agents.nix` |
| A tool or setting on the Mac only | `hosts/mac/home.nix` |
| A Mac app | `homebrew.casks` in `hosts/mac/default.nix` |
| A Homebrew formula that nixpkgs does not have | `homebrew.brews` and `taps` in `hosts/mac/default.nix` |
| A macOS setting | `system.defaults` in `hosts/mac/default.nix` |
| A work setting | `hosts/work-wsl/home.nix`. A system setting goes in `hosts/work-wsl/default.nix`. |
| A system setting on all NixOS machines | `modules/nixos/default.nix` |
| A setting on all lab boxes | `modules/nixos/server.nix` |
| A setting on one lab box | `hosts/lab-N/default.nix` |
| A value that more than one machine uses: username, email, a public key | `vars.nix` |
| The source of a package (release or unstable) | `overlay.nix` |
| A package that nixpkgs does not have | `pkgs/`. See [Add a package that nixpkgs does not have](#add-a-package-that-nixpkgs-does-not-have). |
| A secret | 1Password, then `modules/secrets.nix`. See [Add a secret](secrets.md#add-a-secret). |

## Apply a change

1. Run `nix flake check`.
2. Apply:

   | Machine | Command |
   | --- | --- |
   | Mac | `rebuild` |
   | Work laptop (WSL) | `rebuild` |
   | All lab boxes | `colmena apply`, on the Mac, in `~/.nix-config` |
   | One lab box | `colmena apply --on lab-2`, on the Mac, in `~/.nix-config` |

To see a value before you apply, run `nix repl`, then `:lf .`, then the option path. For
example: `darwinConfigurations.mac.config.home-manager.users.josh.programs.git.settings`.

## Add a package that nixpkgs does not have

1. Write the package in `pkgs/<name>.nix`.
2. Add it to `pkgs/default.nix`.
3. Add its name to the `inherit (unstable)` list in `overlay.nix`.
4. Add its name to `packages` in `flake.nix`.
5. Add the package to the configuration, for example to `home.packages`.

## When nixpkgs has an older version

cache.nixos.org has only the packages that nixpkgs defines. If you change the version of a
package, every machine and every orb builds it from source. For a Rust or Go tool, that can
take 20 minutes or more.

1. Wait for nixpkgs, if you can. A version that is on nixpkgs `master` reaches
   `nixpkgs-unstable` in a few days.
2. If you cannot wait, use the release binaries from upstream, as `pkgs/atuin.nix` and
   `pkgs/lisette.nix` do. Use a static build for Linux (`musl` in the name) where there is
   one, so NixOS needs no patching.
3. Build from source only if upstream has no binaries.
4. Write in the package file when to remove it, for example "Drop once nixpkgs reaches
   18.23.0".

## Change the version of a package in pkgs/

1. Change the version.
2. Set the hash to `lib.fakeHash`.
3. Build the package, for example:

   ```sh
   nix build .#atuin
   ```

4. Copy the correct hash from the error into the file.

## Update everything

Do this about once a week, in this order:

1. [Update inputs](#update-inputs). Record the change. Apply it on each machine.
2. On each machine that you use, run:

   ```sh
   topgrade
   ```

Nix pins the tools in the configuration. topgrade updates what Nix does not pin: Homebrew
and its apps, the npm tools (cf and others), `uv tool` installs, the coding agents, Neovim
plugins, rustup toolchains, and Determinate Nix on the Mac. `home/topgrade.nix` configures it.

Apply first, so that topgrade updates what the new configuration installs.

## Update inputs

1. Update all inputs:

   ```sh
   nix flake update
   ```

   To update one input: `nix flake update nixpkgs`.

   Run it on the Mac or in an orb. Rex's input needs a login that only they have
   ([Rex](rex.md#the-package-login)).

2. Optional: compare the new Mac configuration with the current one:

   ```sh
   nix store diff-closures /run/current-system $(nix build --no-link --print-out-paths .#darwinConfigurations.mac.system)
   ```

3. Apply it on each machine.

If an update breaks a machine:

1. Restore `flake.lock` to its version before the update.

2. Apply.
3. Update one input at a time. Apply after each. Stop at the input that breaks the machine.

## Roll back

> **Warning:** On the Mac, a rollback removes Homebrew apps that the older generation does not
> declare. This can remove 1Password.

| Machine | Command |
| --- | --- |
| Mac | `rebuild --rollback` |
| Work laptop (WSL) | `sudo nixos-rebuild switch --rollback` |
| Lab box | `ssh lab-2 sudo nixos-rebuild switch --rollback` |

If a lab box does not start, select an older generation in its boot menu.

## Clean up

```sh
sudo nix-collect-garbage --delete-older-than 30d
```

Lab boxes do this every day.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `path '…' does not exist` for a new file | Nix sees only the files that version control tracks | Track the file |
| A GitHub rate limit error during an update | Nix has no GitHub token | Run `gh auth login`. Apply again. |
| `HTTP error 404` for `github.com/joshuadavidthomas/yonder.dev/archive/…` | yonder is private, and Nix has no GitHub token. On the Mac, `rebuild` passes yours to `sudo`; a bare `sudo darwin-rebuild` does not. | Run `gh auth login`. Apply again with `rebuild`. |
| `gh config set` fails on a read-only file | home-manager writes `~/.config/gh/config.yml` | Set it in `programs.gh.settings` in `home/git.nix` |
| home-manager stops and names a `.bak` file | An old backup is in the way | Move the old `.bak` file. Apply again. |
| `infinite recursion encountered` | A module reads `config` to decide what to define | Put the condition in `lib.mkIf` on the value, not around `imports` |

## Option search

- [NixOS](https://search.nixos.org/options)
- [home-manager](https://home-manager-options.extranix.com)
- [nix-darwin](https://nix-darwin.github.io/nix-darwin/manual/index.html)
