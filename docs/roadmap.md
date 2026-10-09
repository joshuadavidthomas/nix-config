# Roadmap

## WSL

- [x] Apply `work-wsl` with the new `home/`
- [x] Get the age key from 1Password on WSL: set `secrets.op` to the Windows `op.exe`
- [x] Test commit signing with `op-ssh-sign.exe`
- [ ] Rename the user to `josh` on the work laptop. See
      [Rename the user on an installed system](new-wsl.md#rename-the-user-on-an-installed-system).

## Homelab

- [x] Set up `lab-2` and `lab-3`
- [ ] Secrets on the lab boxes, with age keys from their SSH host keys. Start with a Tailscale
      auth key.
- [ ] A binary cache on one lab box
- [ ] Lab boxes as remote builders for each other and for the Mac
- [ ] `system.autoUpgrade` on the lab boxes

## Monitoring

Design: [Homelab monitoring](research/homelab-monitoring.md).

- [ ] A Fly machine with VictoriaMetrics, VictoriaLogs, vmalert and Grafana
- [ ] Vector on the lab boxes, in `modules/server.nix`
- [ ] Alert rules in vmalert
- [ ] A heartbeat Worker on Cloudflare
- [ ] Agent access through the VictoriaMetrics MCP server
- [ ] A second Vector sink to Cloudflare Basin

## Mac

- [ ] Declare the apps that Homebrew does not install
- [ ] Declare macOS settings: Finder, trackpad, appearance
- [ ] Declare login items
- [ ] Move the remaining tokens (Claude, gh, Todoist) into sops
- [ ] Garbage collection

## All machines

- [ ] Pin SSH host keys (GitHub, Forgejo, lab boxes) in `modules/known-hosts.nix`
- [ ] A CI job that opens pull requests for `flake.lock` updates
