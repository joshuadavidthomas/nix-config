# Rex on the lab boxes

[Rex](https://www.superlogical.com/rex/docs/linux/installation) is the terminal multiplexer from
Superlogical. Each lab box runs its Linux server, from the Rex flake's NixOS module, so Rex for
Mac and Rex for iOS can open sessions on the boxes. The reasons are in [Decisions](decisions.md#rex).

## What each box runs

`modules/nixos/server.nix` turns on Rex's login server, `rex-login-server.service`:

- It runs as root. It asks the box's tailscaled who each caller is, and maps the caller to an
  account with `/etc/rex/accounts.jsonc`. Your Tailscale login,
  `joshuadavidthomas@github`, may use `josh`, and gets it when it names no account.
- It starts a Rex server as that account and passes the connection to it. Sessions survive
  restarts and upgrades of the login server. An account server keeps the old version until
  its sessions end.
- It listens on `/run/rex/login-server.sock`, and on the tailnet in HTTPS through Tailscale
  Serve, on Rex's port, 7297, at `lab-1.tail014d2.ts.net`. `rex-tailscale-serve.service`
  sets up the mapping. Port 443 stays free.
- The module also installs `rex` for every user, its terminfo, and the SSH fallback to
  `xterm-256color`.

Who reaches port 7297 is the tailnet policy's job (`tailscale-acls`). Members reach every
port on the boxes. Orbs reach port 22 only.

## Connect

In Rex for Mac's **Add Remote Host…** and in Rex for iOS, with Tailscale on in the iPhone,
use the full name and the port:

```text
https://lab-1.tail014d2.ts.net:7297
```

Rex for iOS doesn't find the port by itself.

The HTTPS certificate covers only the full name, so a bare `lab-1` gets `tls: internal error`.
On the command line, `lab-1`, `lab-2` and `lab-3` are host labels for the full names, declared
with `rex.host` in `home/files/rex/init.lua`, so `rex -S lab-1 ls` works on every machine. Those labels are for the CLI only: the apps keep
their own host lists and don't read them. After a `rebuild`, run `rex config reload` so the
running server reads the labels.

You don't need `rex server tailscale pair`. It shows a QR code of the address of Rex's
built-in Tailscale, which only a personal or shared server has, so on a box it says
`tailscale is off`. Type the address instead.

From the command line:

```sh
rex -S lab-1 ls
```

On a box, `sudo systemctl status rex-login-server rex-tailscale-serve` shows the server and
the Serve mapping, `journalctl -u rex-login-server` the login server's log, and
`rex server status` your account's server.

## Keybinds and PATH

Each Rex server reads its own `~/.config/rex/init.lua`, so a session on a lab box uses the
box's copy, not the Mac's. `home/files/rex` gives every machine the same file, from
`home/cli.nix`. A running server reads it again only after `rex config reload`, which must
run on that machine as you: `ssh lab-1 rex config reload`.

Rex puts the `rex` that matches its server first in `PATH`, as `REX_BIN_DIR`. NixOS and
nix-darwin set `PATH` again when fish starts, so `home/fish.nix` moves `REX_BIN_DIR` back to
the front.

## The package login

Until Rex's first release, `pkgs.superlogical.com` asks for a login. The flake input in
`flake.nix` comes from there, so whatever evaluates the lab boxes needs the login in a netrc
file. The token is kept on its own; each place writes the netrc line from it:

| Where | Token | Netrc |
| --- | --- | --- |
| Mac | The field `password` of the item "Rex packages" in `dotfiles`. opnix writes it to `~/Library/Application Support/opnix/rexToken`. | `~/.config/nix/netrc`, written by the launchd agent `rex-netrc` at login and when the token file changes (`hosts/mac/home.nix`) |
| Lab boxes | The same field. opnix writes it to `/var/lib/opnix/secrets/rexToken`. | `/var/lib/nix-credentials/netrc`, written by `nix-credentials.service` (`modules/nixos/server.nix`) |
| Orbs | The Amp project secret `REX_PACKAGE_TOKEN` | `~/.config/nix/netrc`, written by `.agents/resume` |

Each names the file with `netrc-file`: in `~/.config/nix/nix.conf` on the Mac and in orbs, in
`/etc/nix/nix.conf` on the lab boxes. The line is:

```text
machine pkgs.superlogical.com login rex password TOKEN
```

The Rex binary comes from `blob.superlogical.com`, which needs no login; only the flake does.
WSL and the Mac's own `rebuild` need none: Nix fetches an input only when a configuration
uses it, and only the lab boxes use Rex. nixos-anywhere, `nix flake update` and
`nix flake check` do need it, so run them on the Mac or in an orb.

Determinate Nix on the Mac reads only the netrc that `netrc-file` names, and it names its
own. The one in `~/.config/nix/nix.conf` applies to you only, and has no FlakeHub login,
which nothing here uses.

## Update Rex

The input follows the `snapshot` channel, a build of every change. `flake.lock` pins one
build. To move to the newest:

```sh
nix flake update rex
```

Then push, and `rebuild` each box. The `preview` and `stable` channels are other URLs; see the comments in
the Rex flake.

## Change the password

1. Change the field `password` of "Rex packages" in 1Password. Fetch the secrets again on the
   Mac and on each lab box (see [Change a secret](secrets.md#change-a-secret)). The Mac's
   agent and the boxes' `nix-credentials` rewrite the netrc.
2. Change the Amp project secret `REX_PACKAGE_TOKEN` of `joshthomas/nix-config`. Orbs that
   start later get it.
