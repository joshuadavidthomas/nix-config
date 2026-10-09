# How secrets work

Nix copies the contents of each `.nix` file into `/nix/store`. All users can read the store.
So the configuration must not contain secrets. This repo gets secrets to a machine in two
ways: 1Password and sops.

## 1Password and sops

1Password contains the SSH keys. Machines use the keys through the 1Password agent, so no
private key is on disk. 1Password also contains the sops age key, as the document
"nix-config sops age key".

All other secrets are in `secrets/`, encrypted with sops for that age key. The encrypted
files are in git. Without the key, they are not useful to anyone. This is why the repo can be
public.

The MonoLisa fonts have a license, so the repo contains them only in encrypted form. Before
the repo became public, `git filter-repo` removed the old unencrypted copies from the history.

All machines use the same age key. For one person with a few machines, a key for each machine
adds work and little security, and 1Password already protects the key. The homelab boxes
cannot use 1Password. They will get keys made from their SSH host keys.

## How a Mac gets the key

The `sopsAgeKey` step in `home/secrets.nix` runs when you apply the configuration. If the key
is missing and 1Password is signed in, the step gets the key from 1Password. It writes the key
to `~/.config/sops/age/keys.txt`. Later steps use this file to decrypt secrets.

Three details are important:

- Activation steps do not get your PATH. So the step calls `op` at `/usr/local/bin/op`.
  `programs._1password` installs it there. The 1Password CLI integration accepts no other
  location.
- `op whoami` does not ask you to unlock 1Password. If you wait for it while 1Password is
  locked, you wait forever. A request for the document opens the Touch ID prompt.
- On macOS, sops looks for its key in `~/Library`. `SOPS_AGE_KEY_FILE` sends it to the path
  above.

## Why the repo does not use sops-nix

sops-nix is the usual way to use sops with Nix. Its home-manager module decrypts secrets in
the background, with launchd or systemd. Nothing makes sure that it finishes before the steps
that need the secrets, for example the atuin login. Also, systemd user services are not
reliable on WSL.

So the steps that need a secret run `sops` themselves. They run in order, and they keep the
secret in memory. Only the fonts go to disk, because macOS ignores fonts that are symlinks.

## The GitHub token for Nix

Nix downloads flake inputs from GitHub. Without a token, GitHub allows 60 requests an hour.
An update can use more.

After `gh auth login`, gh has a token. At each switch, a step in `home/nix.nix` copies it to
`~/.config/nix/access-tokens.conf`, with mode 0600. The Nix user configuration includes that
file with `!include`. If the file is missing, Nix skips it. The token does not go into the repo
or the store.

nix-darwin cannot set this in the system configuration. Determinate Nix controls `/etc/nix`.

## The atuin login

atuin sync needs a username, a password and an encryption key. They are in
`secrets/secrets.yaml`. When `atuin status` shows that atuin is not logged in, a step logs it
in.

An atuin account made through GitHub sign-in has no password. The account needed a password
before the CLI could log in.
