# Roadmap

For the work so far, see [History](explanation/history.md).

| Phase | Where | Goal | Status |
| --- | --- | --- | --- |
| 0 | Work laptop | NixOS-WSL next to the old distribution, with flakes | Done |
| 1 | Work laptop | This repo, a WSL host, the shared home-manager configuration | Done. Needs a new switch (see [WSL](#wsl)). |
| 2 | Projects | devenv in place of mise, setup scripts and docker-compose | One project (dashtext). Other projects use mise. |
| 3 | Mac | nix-darwin and home-manager on all Apple Silicon Macs | Done |
| 4 | Homelab | NixOS boxes, installed and deployed from the Mac | `lab-1` runs |

## Tests for done

Phase 1:

- A new switch changes nothing.
- The daily tools come from home-manager.
- `ssh -T git@github.com` and `gh auth status` succeed.
- You did one rollback on purpose.

Phase 2:

- One real project runs only from `devenv up`.
- `devenv test` passes on your machine and in CI.

Phase 3:

- A new `rebuild` changes nothing.
- The shell and tools are the same as on the other machines.
- You did one rollback.

Phase 4:

- `lab-1`, `lab-2` and `lab-3` are reachable by name over Tailscale.
- One `colmena apply` updates all three.
- You rolled back one box from the boot menu.

## Open work

### WSL

Nobody has applied the WSL host since the Mac changes to `home/`. Before the next switch:

- Set `secrets.op` to the Windows `op.exe`, or put the age key on the machine by hand. Now it
  points to the Mac path `/usr/local/bin/op`.
- Expect atuin, cf, lisette and llm to build from source.
- Test commit signing. The repo uses `op-ssh-sign.exe`. The plan used `op-ssh-sign-wsl.exe`,
  because the first cannot read the Linux paths that git gives it.

### Homelab

- Install `lab-2` and `lab-3`.
- Roll back `lab-1` from the boot menu one time.
- Add secrets to the boxes, with keys from their SSH host keys. Start with a Tailscale auth
  key.
- Add a binary cache on one box.
- Use the boxes as remote builders for each other and for the Mac.
- Turn on `system.autoUpgrade` when `flake.lock` updates are routine.

### Mac

- Declare the apps that Homebrew does not install, as casks or through `mas`.
- Declare macOS settings: Finder, trackpad, appearance.
- Declare login items.
- Move the remaining tokens (Claude, gh, Todoist) into sops.
- Set up garbage collection.

### All machines

- Pin SSH host keys (GitHub, Forgejo, the lab boxes) in `modules/known-hosts.nix`.
- Add a CI job that opens pull requests for `flake.lock` updates.
- Move the remaining projects from mise to devenv.
