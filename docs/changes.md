# Changes

For the file to edit, see [Where a change goes](../README.md#where-a-change-goes).

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
