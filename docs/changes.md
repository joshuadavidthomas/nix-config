# Changes

## Where a change goes

| To add or change | Edit |
| --- | --- |
| A command-line tool or language, on all machines | `home.packages` in `home/default.nix` |
| A tool that is already configured | The file in `home/` that configures it |
| A coding agent, or its settings and hooks | `home/agents.nix` |
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
| A secret | `secrets/`. See [Secrets](secrets.md). |

## Apply a change

1. Run `nix flake check`.
2. Record the change:

   ```sh
   jj describe -m "Add ripgrep"
   jj new
   ```

3. Apply:

   | Machine | Command |
   | --- | --- |
   | Mac | `rebuild` |
   | Work laptop (WSL) | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
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

## Change the version of a package in pkgs/

1. Change the version.
2. Set the hash to `lib.fakeHash`.
3. Build the package, for example:

   ```sh
   nix build .#atuin
   ```

4. Copy the correct hash from the error into the file.

For cf, follow the steps in `pkgs/cf/default.nix`.

## Update inputs

1. Update all inputs:

   ```sh
   nix flake update
   ```

   To update one input: `nix flake update nixpkgs`.

2. Optional: compare the new Mac configuration with the current one:

   ```sh
   nix store diff-closures /run/current-system $(nix build --no-link --print-out-paths .#darwinConfigurations.mac.system)
   ```

3. Record the change. Apply it on each machine.

If an update breaks a machine:

1. Restore the lock file from the change before the update:

   ```sh
   jj restore --from <change> flake.lock
   ```

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
| `path '…' does not exist` for a new file | jj did not record the file | Run `jj status` |
| `git commit` makes an empty commit | jj recorded the change first | Use `jj describe` and `jj new`. Remove the empty commit with `jj abandon`. |
| A GitHub rate limit error during an update | Nix has no GitHub token | Run `gh auth login`. Apply again. |
| `gh config set` fails on a read-only file | home-manager writes `~/.config/gh/config.yml` | Set it in `programs.gh.settings` in `home/git.nix` |
| home-manager stops and names a `.bak` file | An old backup is in the way | Move the old `.bak` file. Apply again. |
| `infinite recursion encountered` | A module reads `config` to decide what to define | Put the condition in `lib.mkIf` on the value, not around `imports` |

## Option search

- [NixOS](https://search.nixos.org/options)
- [home-manager](https://home-manager-options.extranix.com)
- [nix-darwin](https://nix-darwin.github.io/nix-darwin/manual/index.html)
