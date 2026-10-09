# Commands

## Applying

| Task | Command |
| --- | --- |
| Apply the Mac | `rebuild` |
| Roll back the Mac | `rebuild --rollback` |
| Apply WSL | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| Roll back WSL | `sudo nixos-rebuild switch --rollback` |
| Deploy every homelab box | `colmena apply` |
| Deploy one box | `colmena apply --on lab-2` |
| See what a box runs | `ssh lab-1 nixos-version` |

## Flake

| Task | Command |
| --- | --- |
| Update every input | `nix flake update` |
| Update one input | `nix flake update nixpkgs` |
| Evaluate and build checks | `nix flake check` |
| Build one package | `nix build .#llm` |
| Inspect the config | `nix repl`, then `:lf .` |

## Packages

| Task | Command |
| --- | --- |
| Run a tool once | `nix run nixpkgs#<pkg>` |
| Shell with tools on PATH | `nix shell nixpkgs#a nixpkgs#b` |
| Find a package | `nix search nixpkgs <term>` |
| Show a package's dependencies and sizes | `nix path-info -rsSh nixpkgs#<pkg>` |
| Compare two systems | `nix store diff-closures <old> <new>` |

## Secrets

| Task | Command |
| --- | --- |
| Edit secrets | `sops secrets/secrets.yaml` |
| Read one value | `sops decrypt --extract '["atuin"]["username"]' secrets/secrets.yaml` |

## devenv

| Task | Command |
| --- | --- |
| Create an environment | `devenv init` |
| Enter it | `devenv shell` (direnv does this on `cd`) |
| Start services and processes | `devenv up` |
| Run the project's checks | `devenv test` |
| Bump pinned inputs | `devenv update` |
| Delete old environments | `devenv gc` |

## Cleanup

| Task | Command |
| --- | --- |
| Delete unreferenced store paths | `nix store gc` |
| Delete generations older than 30 days | `sudo nix-collect-garbage --delete-older-than 30d` |

## Version control (jj)

| Task | Command |
| --- | --- |
| Name the current change | `jj describe -m "…"` |
| Start the next change | `jj new` |
| Drop a change | `jj abandon <change>` |
| Restore a file from another change | `jj restore --from <change> <path>` |
| Push | `jj bookmark set main -r <change> && jj git push -b main` |
