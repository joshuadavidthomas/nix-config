# Roadmap

## WSL

- [ ] Apply `work-wsl` with the new `home/`
- [ ] Get the age key from 1Password on WSL: set `secrets.op` to the Windows `op.exe`
- [ ] Test commit signing with `op-ssh-sign.exe`

## Homelab

- [ ] Set up `lab-2` and `lab-3`
- [ ] Roll back `lab-1` from the boot menu once
- [ ] Secrets on the lab boxes, with age keys from their SSH host keys. Start with a Tailscale
      auth key.
- [ ] A binary cache on one lab box
- [ ] Lab boxes as remote builders for each other and for the Mac
- [ ] `system.autoUpgrade` on the lab boxes

## Mac

- [ ] Declare the apps that Homebrew does not install
- [ ] Declare macOS settings: Finder, trackpad, appearance
- [ ] Declare login items
- [ ] Move the remaining tokens (Claude, gh, Todoist) into sops
- [ ] Garbage collection

## All machines

- [ ] Pin SSH host keys (GitHub, Forgejo, lab boxes) in `modules/known-hosts.nix`
- [ ] A CI job that opens pull requests for `flake.lock` updates
