# Roadmap

Status of the move to Nix. [How the move to Nix went](explanation/history.md) has the story so
far.

| Phase | Where | Goal | Status |
| --- | --- | --- | --- |
| 0 | Work laptop | NixOS-WSL beside the old distro, flakes on | Done |
| 1 | Work laptop | This repo, a WSL host, and the shared home-manager config | Done, but needs a rebuild (below) |
| 2 | Projects | devenv replaces mise, setup scripts and docker-compose | dashtext is piloting it; other projects still use mise |
| 3 | Mac | nix-darwin and home-manager on any Apple Silicon Mac | Done |
| 4 | Homelab | NixOS boxes installed and deployed from the Mac | `lab-1` is up |

## Done when

Phase 1 is done when a fresh switch is a no-op, daily CLI tools come from home-manager,
`ssh -T git@github.com` and `gh auth status` both succeed, and you've rolled back once on
purpose.

Phase 2 is done when one real project runs entirely from `devenv up` and passes `devenv test`
locally and in CI.

Phase 3 is done when a fresh `rebuild` is a no-op, the shell and tools match the other
machines, and you've rolled back once.

Phase 4 is done when all three boxes are reachable as `lab-1`…`lab-3` over Tailscale, one
`colmena apply` updates them all, and you've rolled one back from the boot menu.

## Still open

### WSL

The WSL host hasn't been rebuilt since the Mac work reshaped `home/`. Before it switches
cleanly:

- `secrets.op` points at the Mac's `/usr/local/bin/op`. WSL needs Windows' `op.exe`, or the
  age key placed by hand.
- atuin, cf, lisette and llm will build from source on the first switch.
- The git signer is `op-ssh-sign.exe`. The original plan called for `op-ssh-sign-wsl.exe`,
  because the plain one can't read the Linux temp-file path git hands it. Test a signed commit.

### Homelab

- Install `lab-2` and `lab-3`.
- Roll `lab-1` back once from the boot menu.
- Secrets on the boxes: sops with age keys from each box's SSH host key, starting with a
  Tailscale auth key.
- A binary cache on one box, trusted by the others.
- The boxes as remote builders for each other and the Mac.
- `system.autoUpgrade`, once updating `flake.lock` is routine.

### Mac

- Apps installed outside Homebrew, declared as casks or through `mas`.
- macOS defaults: Finder, trackpad, appearance.
- Login items.
- The remaining tokens (Claude, gh, Todoist) through sops.
- Garbage collection.

### Everywhere

- Pin SSH host keys (GitHub, Forgejo, the lab boxes) in a shared `modules/known-hosts.nix`, so
  no machine shows a first-connection prompt.
- A CI job that opens pull requests updating `flake.lock`.
- devenv for the projects still on mise.
