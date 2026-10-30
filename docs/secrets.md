# Secrets

All secrets are in 1Password. Each machine reads them with [opnix](https://github.com/brizzbuzz/opnix)
and a 1Password service account. The reasons are in [Decisions](decisions.md#secrets).

## Where each secret is

| What | Where |
| --- | --- |
| Secrets that the machines read | 1Password, the vault `dotfiles` |
| The service account token | 1Password, the item "Service Account Auth Token: dotfiles" in the Private vault |
| The token on a machine | `/etc/opnix-token` |
| Secrets on a NixOS machine | `/var/lib/opnix/secrets/<name>` |
| Secrets on a Mac | `~/Library/Application Support/opnix/<name>`. The MonoLisa fonts are in `~/Library/Fonts`. |
| SSH keys and the git signing key of the Mac and WSL | 1Password. These machines use them through the 1Password SSH agent. |
| The git signing key of the lab boxes | 1Password, the item "Lab signing key" in `dotfiles` |
| The Tailscale OAuth client of the lab boxes | 1Password, the item "Homelab Tailscale OAuth" in `dotfiles` |
| The GitHub token of the lab boxes, to fetch yonder | 1Password, the field `password` of the item "Lab GitHub token" in `dotfiles`. Each box writes it into `/var/lib/nix-credentials/access-tokens.conf`, which `wheel` can read: `/etc/nix/nix.conf` includes it, and Nix ignores all of `nix.conf` for a user who cannot look inside `/var/lib/nix-credentials`. |
| Rex's package token | 1Password, the field `password` of the item "Rex packages" in `dotfiles`. The Mac writes it into `~/.config/nix/netrc`, a lab box into `/var/lib/nix-credentials/netrc`. Orbs get it from the Amp project secret `REX_PACKAGE_TOKEN`. See [Rex](rex.md#the-package-login). |
| yonder's coordinator token and each lab box's Cloudflare Access service token | `/etc/yonder/coordinator.env` on each lab box, placed by hand, not by opnix. See [yonder](yonder.md#the-files-on-each-box). |

The service account can read `dotfiles` and nothing else. It cannot write.

## How the secrets get to a machine

`modules/secrets.nix` declares the secrets that every machine gets. `hosts/mac/default.nix`
adds the fonts and Rex's package login. `modules/nixos/server.nix` adds the signing key, the Tailscale client, the GitHub token and Rex's token of the lab boxes.

opnix runs as a system service: systemd on NixOS, launchd on a Mac. It fetches every secret
when its list of secrets changes and when the machine starts. An apply does not wait for it,
except that home-manager waits for it on NixOS. On NixOS a failed fetch is retried after 10
seconds, at most 5 times an hour (`modules/nixos/default.nix`), not opnix's own 15 minutes:
at boot the first fetch can fail while DNS is still coming up.

On a lab box, `nix-credentials.service` writes the GitHub token and Rex's token into Nix's
files in `/var/lib/nix-credentials`. It runs at boot, again when opnix changes a token, and
again when an apply changes the service.

## Put the token on a machine

Each machine copies the token from 1Password to `/etc/opnix-token` when you apply. The token
item is set in `vars.opnixTokenArgs`.

| Machine | When | How |
| --- | --- | --- |
| New lab box | The install | nixos-anywhere copies the Mac's `/etc/opnix-token`. See [Set up a lab box](new-lab-box.md#install). |
| Mac | `rebuild`, if the token is missing | `op` with the 1Password app. 1Password must be unlocked. |
| WSL | `rebuild`, if the token is missing | `op.exe` with 1Password for Windows |
| New Mac | The bootstrap | `op` with the 1Password app, after you sign in |

## Add a secret

1. Add the item to the vault `dotfiles`, or add a field to an item that is there.
2. Declare the secret in `services.onepassword-secrets.secrets`. For a secret on every
   machine, use `modules/secrets.nix`. For a secret on some machines, use `hosts/` or
   `modules/nixos/server.nix`. The name must be camelCase, for example `atuinPassword`.
3. Use the file at `config.services.onepassword-secrets.secretPaths.<name>`. In home-manager,
   use `osConfig` in place of `config`.

The reference is `op://dotfiles/<item>/<field>`. For a Document or an attached file, set
`kind = "file"` and use `op://dotfiles/<item>/<file name>`.

## Change a secret

1. Change it in 1Password.
2. Fetch the secrets again on each machine:

   | Machine | Command |
   | --- | --- |
   | Mac | `sudo launchctl kickstart -k system/org.nixos.opnix-secrets` |
   | Lab box, from the Mac | `ssh lab-2 sudo systemctl restart opnix-secrets` |
   | WSL | `sudo systemctl restart opnix-secrets` |

## Replace the service account token

1. In 1Password, on the service account, make a new token. Save it in the token item.
   Revoke the old token.
2. On the Mac and WSL, remove the old token, then apply: `sudo rm /etc/opnix-token`, then
   `rebuild`.
3. Copy the Mac's new token to each lab box. Your user on the Mac can read it:

   ```sh
   for box in lab-1 lab-2 lab-3; do ssh $box 'sudo sh -c "umask 077; cat > /etc/opnix-token"' < /etc/opnix-token; done
   ```

4. Fetch the secrets again. See [Change a secret](#change-a-secret).

## The Tailscale client

A new lab box joins Tailscale with the secret of a Tailscale OAuth client, with the tag `lab`.
The lab box gives the client secret to `tailscale up` in place of an auth key, and Tailscale
makes a new auth key from it each time. The client secret does not expire; only the auth
keys that it makes do. Make the client once:

1. In the Tailscale admin console, open Settings > Trust credentials. Add a credential of
   the kind OAuth. Give it the scope Auth Keys (`auth_keys`), with Write, and the tag
   `tag:lab`.
2. Copy the client secret. It starts with `tskey-client-`. Tailscale shows it only once.
3. In 1Password, in the vault `dotfiles`, make an item named "Homelab Tailscale OAuth".
   Put the client secret in the field `client secret`. The lab boxes do not use the client
   ID; keep it in the field `client id` for reference.

The tag `lab` must be in `tagOwners` in the tailnet policy. A lab box that is already on the
tailnet keeps its node: the client is used only when a lab box is logged out.

To replace the client, make a new one, put its secret in the item, and delete the old one.

## The GitHub token of the lab boxes

A lab box fetches the flake's inputs itself when it runs `rebuild`. yonder is a private repo,
so the box needs a GitHub token that can read it.

1. On GitHub, make a fine-grained personal access token: Settings > Developer settings >
   Fine-grained tokens. Repository access: only `joshuadavidthomas/yonder.dev`. Permissions:
   Contents, read-only. A fine-grained token reads public repos too.
2. Save it in 1Password, in `dotfiles`, as the field `password` of the item
   "Lab GitHub token":

   ```sh
   read -rs TOKEN && op item create --vault dotfiles --category Password --title "Lab GitHub token" "password=$TOKEN"; unset TOKEN
   ```

3. Fetch the secrets again on each lab box. See [Change a secret](#change-a-secret).

When the token expires, make a new one and change the field.

## Rate limit

1Password Families allows 1,000 service account requests a day for the whole account. Each
fetch reads each secret once. To see the use:

```sh
op service-account ratelimit
```

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `rebuild: couldn't read the opnix token from 1Password` | 1Password is locked, or its CLI integration is off | Unlock 1Password. Turn on Settings > Developer > Integrate with 1Password CLI. Run `rebuild` again. |
| `atuin: opnix hasn't fetched the account from 1Password yet` | opnix had no token, or has not finished | Apply again |
| `Token file /etc/opnix-token does not exist` in the opnix log | No token | Apply again. See [Put the token on a machine](#put-the-token-on-a-machine). |
| Commits on a lab box fail with a signing error | opnix has not written the signing key | Run `ssh <box> sudo systemctl restart opnix-secrets` |
| `dial tcp: lookup …1password.com` in the opnix log, at boot | DNS was not up yet | None: it retries in 10 seconds |
| A secret is old | opnix fetches only when its list changes or the machine starts | See [Change a secret](#change-a-secret) |

The opnix log is `journalctl -u opnix-secrets` on NixOS and `/var/log/opnix-secrets.log` on a Mac.
