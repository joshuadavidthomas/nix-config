# Secrets

## Where each secret is

| What | Where |
| --- | --- |
| SSH keys and the git signing key | 1Password. Machines use them through the 1Password SSH agent. |
| The age key | 1Password, the document "nix-config sops age key" |
| The age key on a machine | `~/.config/sops/age/keys.txt` |
| Other secrets | `secrets/`, encrypted with sops |
| The keys that can decrypt `secrets/` | `.sops.yaml` |

On a Mac, the `sopsAgeKey` step in `home/secrets.nix` gets the age key from 1Password at each
apply until the key is present. 1Password must be unlocked, with the CLI integration on.

## Put the age key on a machine

Do this on machines other than a Mac. On a Mac, unlock 1Password and apply again.

1. Make the directory:

   ```sh
   mkdir -p -m 700 ~/.config/sops/age
   ```

2. Get the age key from 1Password:

   ```sh
   op document get "nix-config sops age key" > ~/.config/sops/age/keys.txt
   ```

   If `op` is not installed, copy the document into the file by hand.

3. Limit access to the file:

   ```sh
   chmod 600 ~/.config/sops/age/keys.txt
   ```

## Change a secret

1. Open the secrets file:

   ```sh
   sops secrets/secrets.yaml
   ```

2. Change the value. Save the file.
3. Record the change.

To read one value:

```sh
sops decrypt --extract '["atuin"]["username"]' secrets/secrets.yaml
```

To use a secret in the configuration, decrypt it in a step that runs after `sopsAgeKey`. The
`monolisa` step in `hosts/mac/home.nix` is an example.

## Add an encrypted file

1. Encrypt the file:

   ```sh
   sops encrypt --filename-override secrets/fonts/font.ttf.json \
     --input-type binary --output-type json font.ttf > secrets/fonts/font.ttf.json
   ```

2. In the step that uses the file, decrypt it with `--input-type json --output-type binary`.

## Add or replace an age key

1. Change `keys` in `.sops.yaml`.
2. Encrypt each file for the new keys (fish):

   ```sh
   for f in secrets/secrets.yaml secrets/fonts/*.json; sops updatekeys $f; end
   ```

3. If you replaced the age key, put the new key in the 1Password document.
4. Record the change.
