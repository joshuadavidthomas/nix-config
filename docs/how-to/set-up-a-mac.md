# How to set up a new Mac

This takes a fresh Apple Silicon Mac to fully configured. Intel Macs aren't supported; several
of the packages no longer build there.

## Run the bootstrap

In Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
```

It installs Determinate Nix, then switches straight from GitHub. That first switch installs
Homebrew, every app (1Password included) and every tool, and clones this repo to
`~/.nix-config`. The bootstrap is safe to rerun; each step skips what's already done.

If the switch stops on the Xcode license, run the bootstrap again. The config accepts the
license before the Homebrew step, but only once Xcode is installed.

## Sign in to 1Password

When the bootstrap says it's waiting for 1Password:

1. Sign in to the 1Password app.
2. Turn on Settings > Developer > Integrate with 1Password CLI.
3. Turn on Settings > Developer > Use the SSH agent.
4. Approve the Touch ID prompt.

The bootstrap then switches again from `~/.nix-config`. This time the sops age key comes from
1Password, and the secrets fall into place (atuin logs in and syncs, the MonoLisa fonts are
installed).

## Finish up

Open a new terminal; the login shell is now Nix's fish. Then, once per machine:

```sh
gh auth login            # lets Nix use gh's token for GitHub fetches
ssh -T git@github.com    # should greet you by username
```

Run `rebuild` once more so Nix picks up the gh token. It should finish with nothing to change
apart from the token.

From now on, `rebuild` applies `~/.nix-config`. See
[Apply, update and roll back](apply-update-roll-back.md).
