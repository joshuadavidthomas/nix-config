# Secrets

The configuration must not contain secrets. Nix copies it into `/nix/store`, and all users can
read the store.

## How it works

- 1Password holds the SSH keys. Machines use them through the 1Password agent.
- 1Password also holds the sops age key, as the document "nix-config sops age key".
- All other secrets are in `secrets/`, encrypted with sops for that age key. `.sops.yaml` lists
  the key.
- Each machine keeps the age key at `~/.config/sops/age/keys.txt`.
- Activation steps decrypt a secret when they need it, and keep it in memory. They do not write
  it to disk, except fonts.

On a Mac, the `sopsAgeKey` step in `home/secrets.nix` gets the key from 1Password the first
time that you apply the configuration. 1Password must be unlocked, with the CLI integration on.

The repo does not use sops-nix. Its home-manager module decrypts in the background, so the
secrets can arrive after the steps that need them.

## Put the key on a machine

Do this on a machine that is not a Mac, or if the Mac step failed.

1. Make the directory:

   ```sh
   mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
   ```

2. Get the key from 1Password:

   ```sh
   op document get "nix-config sops age key" > ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

If `op` is not available, copy the document contents by hand.

## Change a value

1. Open the secrets file. sops decrypts it in your editor.

   ```sh
   sops secrets/secrets.yaml
   ```

2. Edit the value and save. sops encrypts the file again.
3. Record the change with jj.

To read one value:

```sh
sops decrypt --extract '["atuin"]["username"]' secrets/secrets.yaml
```

## Use a value in the configuration

Decrypt the value in a home-manager activation step that runs after `sopsAgeKey`. The
`monolisa` step in `hosts/mac/home.nix` is an example.

## Add a file

1. Encrypt the file:

   ```sh
   sops encrypt --filename-override secrets/fonts/font.ttf.json \
     --input-type binary --output-type json font.ttf > secrets/fonts/font.ttf.json
   ```

   sops selects its rules by file name. Without `--filename-override`, it fails with
   `no matching creation rules found`.

2. Decrypt it in an activation step with `--input-type json --output-type binary`.

## Add or change a key

1. Add or change the key in `keys` in `.sops.yaml`.
2. Encrypt each file again for the new keys. `sops updatekeys` takes one file at a time. This
   loop is for fish:

   ```sh
   for f in secrets/secrets.yaml secrets/fonts/*.json; sops updatekeys $f; end
   ```

3. Record the change with jj.
