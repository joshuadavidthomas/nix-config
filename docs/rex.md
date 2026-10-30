# Rex on the lab boxes

[Rex](https://www.superlogical.com/rex/docs/linux/installation) is the terminal multiplexer from
Superlogical. Each lab box runs its Linux server, from the Rex flake's NixOS module, so Rex for
Mac can open sessions on the boxes. The reasons are in [Decisions](decisions.md#rex).

## What each box runs

`modules/nixos/server.nix` turns on Rex's login server, `rex-login-server.service`:

- It runs as root. It asks the box's tailscaled who each caller is, and maps the caller to an
  account with `/etc/rex/accounts.jsonc`. Your Tailscale login,
  `joshuadavidthomas@github`, may use `josh`, and gets it when it names no account.
- It starts a Rex server as that account and passes the connection to it. Sessions survive
  restarts and upgrades of the login server. An account server keeps the old version until
  its sessions end.
- It listens on `/run/rex/login-server.sock` and on the box's tailnet addresses, port 7297,
  in plain HTTP inside Tailscale (`tailnet://:7297`).
- The module also installs `rex` for every user, its terminfo, and the SSH fallback to
  `xterm-256color`.

Who reaches port 7297 is the tailnet policy's job (`tailscale-acls`). Members reach every
port on the boxes. Orbs reach port 22 only.

## Connect

In Rex for Mac, choose **Add Remote Host…** and enter `lab-1`. A bare host name tries HTTPS
on 443, then on 7297, then HTTP on 7297.

From the command line:

```sh
rex -S lab-1 ls
```

On a box, `sudo systemctl status rex-login-server` shows the server, and
`journalctl -u rex-login-server` its log.

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
