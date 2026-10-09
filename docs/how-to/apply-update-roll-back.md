# How to apply, update and roll back

## Apply changes

1. Record the change:

   ```sh
   jj describe -m "…"
   jj new
   ```

2. Apply it:

   | Machine | Command |
   | --- | --- |
   | Mac | `rebuild` |
   | NixOS-WSL | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
   | All homelab boxes | `colmena apply` |
   | One homelab box | `colmena apply --on lab-2` |

## Update packages

1. Update the inputs. To update all of them:

   ```sh
   nix flake update
   ```

   To update one input:

   ```sh
   nix flake update nixpkgs
   ```

2. Optional: see what changes on the Mac before you apply:

   ```sh
   nix store diff-closures /run/current-system $(nix build --no-link --print-out-paths .#darwinConfigurations.mac.system)
   ```

   `--no-link` prevents a `result` link in the repo. jj records such links.

3. Apply on each machine.

## Roll back

| Machine | Command |
| --- | --- |
| Mac | `rebuild --rollback` |
| NixOS-WSL | `sudo nixos-rebuild switch --rollback` |
| Homelab box | Reboot the box. Select an older generation in the boot menu. |

> **Caution:** On the Mac, a rollback removes Homebrew apps that the older generation does not
> declare. This includes 1Password. Apply the newer generation to install them again.

## Undo an update

1. Restore the lock file from the change before the update:

   ```sh
   jj restore --from <change> flake.lock
   ```

2. Apply on each machine.
3. Update the inputs one at a time to find the input that caused the problem.

## Deploy an older version to the homelab

1. Start a change on the old version:

   ```sh
   jj new <change>
   ```

2. Deploy it:

   ```sh
   colmena apply
   ```
