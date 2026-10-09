# Add or change a secret

Secrets are in `secrets/`, encrypted with sops. To decrypt them, the machine needs the age key
at `~/.config/sops/age/keys.txt`. A Mac gets this key from 1Password when you first apply the
configuration.

## Change a value

1. Open the secrets file:

   ```sh
   sops secrets/secrets.yaml
   ```

   sops decrypts the file and opens it in your editor.

2. Edit the value and save. sops encrypts the file again.
3. Record the change with jj.

## Use a value in the configuration

Decrypt the value in a home-manager activation step. Then the value does not go into
`/nix/store`. Use the `atuinLogin` step in `home/secrets.nix` as a model:

```nix
{ config, lib, pkgs, ... }:
let
  ageKeyFile = "${config.xdg.configHome}/sops/age/keys.txt";
in
{
  home.activation.example = lib.hm.dag.entryAfter [ "writeBoundary" "sopsAgeKey" ] ''
    if [ -r ${ageKeyFile} ]; then
      value=$(SOPS_AGE_KEY_FILE=${ageKeyFile} ${lib.getExe pkgs.sops} decrypt \
        --extract '["example"]["token"]' ${../secrets/secrets.yaml})
      # use $value here
    fi
  '';
}
```

The step must come after `sopsAgeKey`. That step gets the key.

## Add a file

1. Encrypt the file:

   ```sh
   sops encrypt --filename-override secrets/fonts/font.ttf.json \
     --input-type binary --output-type json font.ttf > secrets/fonts/font.ttf.json
   ```

   sops selects its rules by file name. Without `--filename-override`, it fails with
   `no matching creation rules found`.

2. Decrypt the file in an activation step with `--input-type json --output-type binary`. The
   `monolisa` step in `hosts/mac/home.nix` is an example.

## Put the age key on a machine that is not a Mac

1. Make the directory:

   ```sh
   mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
   ```

2. Get the key from 1Password:

   ```sh
   op document get "nix-config sops age key" > ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

If the 1Password CLI is not available, copy the document contents by hand.
