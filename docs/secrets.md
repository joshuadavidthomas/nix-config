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

The service account can read `dotfiles` and nothing else. It cannot write.

## How the secrets get to a machine

`modules/secrets.nix` declares the secrets that every machine gets. `hosts/mac/default.nix`
adds the fonts. `modules/nixos/server.nix` adds the signing key of the lab boxes.

opnix runs as a system service: systemd on NixOS, launchd on a Mac. It fetches every secret
when its list of secrets changes and when the machine starts. An apply does not wait for it,
except that home-manager waits for it on NixOS.

## Put the token on a machine

Each machine copies the token from 1Password to `/etc/opnix-token` when you apply. The token
item is set in `vars.opnixTokenArgs`.

| Machine | When | How |
| --- | --- | --- |
| Lab box | Each `colmena apply` | colmena copies the Mac's `/etc/opnix-token`. Your user on the Mac can read it. |
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
   `rebuild`. Then run `colmena apply`: the lab boxes get the Mac's new token.
3. Fetch the secrets again. See [Change a secret](#change-a-secret).

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
| Commits on a lab box fail with a signing error | opnix has not written the signing key | Run `colmena apply --on <box>` |
| A secret is old | opnix fetches only when its list changes or the machine starts | See [Change a secret](#change-a-secret) |

The opnix log is `journalctl -u opnix-secrets` on NixOS and `/var/log/opnix-secrets.log` on a Mac.
