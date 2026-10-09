# About secrets

Everything in a `.nix` file ends up in `/nix/store`, which any user on the machine can read.
So the rule is that Nix manages configuration and never holds a secret. Secrets reach a
machine some other way, and this repo uses two.

## 1Password and sops

1Password is the root of trust. It holds the SSH keys (used through its agent, so no machine
has a private key on disk) and one more thing: the sops age key, stored as the document
"nix-config sops age key".

Every other secret lives in `secrets/`, encrypted with sops to that one age key. The encrypted
files are committed, which is safe because they're useless without the key. That's what made
it possible to make the repo public. The licensed MonoLisa fonts went the same way: the repo
carries them only encrypted, and before it went public, earlier plaintext copies were removed
from history with `git filter-repo`.

A single shared age key is a choice of convenience. One person on a few machines doesn't gain
much from a key per machine, and 1Password already guards the one key. The homelab boxes will
be different, because they can't reach 1Password; they'll get keys derived from their own SSH
host keys.

## How a Mac gets the key

On the first switch after 1Password is signed in, a home-manager activation step
(`sopsAgeKey` in `home/secrets.nix`) asks 1Password for the document and writes it to
`~/.config/sops/age/keys.txt`. Every later step that needs a secret decrypts it from there.

Three details took a while to find. Activation runs with a minimal PATH, so `op` is called by
its full path, `/usr/local/bin/op`, which is where `programs._1password` installs it and the
only location 1Password's CLI integration accepts. `op whoami` only reports whether you're
signed in and never prompts, so waiting on it while 1Password is locked waits forever; asking
for the document directly is what brings up Touch ID. And sops on macOS looks for its key
under `~/Library` by default, so `SOPS_AGE_KEY_FILE` points it at the XDG path instead.

## Why not sops-nix

sops-nix is the usual way to use sops with Nix, and it was considered. Its home-manager module
decrypts in the background, through a launchd agent or a systemd user service. Nothing
guarantees that's finished before the activation steps that need the secrets, such as logging
atuin in, and systemd user services are unreliable on WSL. Calling `sops` directly inside the
activation steps that need a value runs in order and decrypts into memory, and only the fonts
are written to disk (macOS ignores symlinked fonts, so they have to be real files).

## The GitHub token for Nix

Nix fetches flake inputs from GitHub, and anonymously it gets 60 API requests an hour, which
an update can use up. gh already holds a token after `gh auth login`, so a home-manager step
(`home/nix.nix`) copies it into `~/.config/nix/access-tokens.conf` (mode 0600) on each switch,
and Nix's user config pulls that file in with `!include`, which skips it if it's missing. The
token never touches the repo or the store. nix-darwin can't set this in the system config,
because Determinate Nix manages `/etc/nix` itself.

## Logging in to atuin

atuin's sync needs a username, password and encryption key. They're in
`secrets/secrets.yaml`, and an activation step logs atuin in whenever `atuin status` says it
isn't. One wrinkle: an atuin account created through GitHub sign-in has no password, so one
had to be added to the account before the CLI could log in.
