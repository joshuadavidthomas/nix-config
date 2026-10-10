# Roadmap

## WSL

- [x] Apply `work-wsl` with the new `home/`
- [x] Test commit signing with `op-ssh-sign.exe`
- [ ] Rename the user to `josh` on the work laptop. See
      [Rename the user on an installed system](new-wsl.md#rename-the-user-on-an-installed-system).

## Homelab

- [x] Set up `lab-2` and `lab-3`
- [ ] A binary cache on one lab box
- [ ] Lab boxes as remote builders for each other and for the Mac
- [ ] `system.autoUpgrade` on the lab boxes

## Secrets

See [Decisions](decisions.md#secrets).

- [x] Create the vault `dotfiles` and a read-only service account for it
- [x] Read secrets from 1Password with opnix, on every machine
- [x] Remove sops: atuin, the MonoLisa fonts (as 1Password Documents), the age key
- [ ] Apply on WSL, so that it gets the opnix token. The Mac and the lab boxes are done.
- [ ] Delete the 1Password document "nix-config sops age key"
- [x] A shared signing key for the lab boxes
- [x] Register the lab signing key on GitHub
- [ ] A Tailscale auth key in 1Password, so that a new lab box joins without the login URL
- [ ] After a few days of use, check `op service-account ratelimit`

## Monitoring

Design: [Homelab monitoring](research/homelab-monitoring.md).

- [ ] A Fly machine with VictoriaMetrics, VictoriaLogs, vmalert and Grafana
- [ ] Vector on the lab boxes, in `modules/nixos/server.nix`
- [ ] Alert rules in vmalert
- [ ] A heartbeat Worker on Cloudflare
- [ ] Agent access through the VictoriaMetrics MCP server
- [ ] A second Vector sink to Cloudflare Basin

## Mac

- [ ] Declare the apps that Homebrew does not install
- [ ] Declare macOS settings: Finder, trackpad, appearance
- [ ] Declare login items
- [ ] Move the remaining tokens (Claude, gh, Todoist) into 1Password
- [ ] Garbage collection

## All machines

- [ ] Pin SSH host keys (GitHub, Forgejo, lab boxes) in `modules/known-hosts.nix`
- [ ] A CI job that opens pull requests for `flake.lock` updates
