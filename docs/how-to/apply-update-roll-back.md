# How to apply, update and roll back

## Apply changes

| Machine | Command |
| --- | --- |
| Mac | `rebuild` |
| NixOS-WSL | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| Every homelab box | `colmena apply` |
| One homelab box | `colmena apply --on lab-2` |

Record the change in jj (`jj describe -m "…"`, then `jj new`) before you apply, so every
generation matches a change in the history.

## Update packages

To update everything:

```sh
nix flake update
```

To update one input:

```sh
nix flake update nixpkgs
```

Then apply on each machine. To see what will change on the Mac before you switch, build the new
system and compare it with the running one:

```sh
nix store diff-closures /run/current-system $(nix build --no-link --print-out-paths .#darwinConfigurations.mac.system)
```

`--no-link` keeps the build from leaving a `result` link in the repo, which jj would record.

## Roll back

| Machine | Command |
| --- | --- |
| Mac | `rebuild --rollback` |
| NixOS-WSL | `sudo nixos-rebuild switch --rollback` |
| Homelab box | Reboot it and pick an older generation in the boot menu |

On the Mac, rolling back to a generation from before a Homebrew cask was added uninstalls
that app, 1Password included, because `cleanup = "uninstall"` removes anything the generation
doesn't declare. Rolling forward reinstalls it.

## Undo an update

If an update broke something, restore the lock file from the change before it and apply again:

```sh
jj restore --from <change> flake.lock
```

Then update inputs one at a time to find the culprit.

## Deploy an older version to the homelab

Start a change on top of the version you want and deploy it:

```sh
jj new <change>
colmena apply
```
