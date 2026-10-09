# How to add or change a secret

Secrets live sops-encrypted in `secrets/`. Your machine needs the age key at
`~/.config/sops/age/keys.txt`; a Mac fetches it from 1Password on its first switch.

## Edit a value

```sh
sops secrets/secrets.yaml
```

sops decrypts the file into your editor and re-encrypts it when you save. Record the change
with jj like any other.

## Use a value during a switch

Decrypt it inside a home-manager activation step, so it never lands in `/nix/store`. Follow
the `atuinLogin` step in `home/secrets.nix`:

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

Order the step after `sopsAgeKey`, which is the step that fetches the key.

## Add a file

For a whole file, such as a font, encrypt it as binary. sops picks its rules from the file
name, so name the destination with `--filename-override`; without it, sops fails with
`no matching creation rules found`.

```sh
sops encrypt --filename-override secrets/fonts/font.ttf.json \
  --input-type binary --output-type json font.ttf > secrets/fonts/font.ttf.json
```

Decrypt it in an activation step with `--input-type json --output-type binary`, as the
`monolisa` step in `hosts/mac/home.nix` does.

## Put the age key on a machine that isn't a Mac

```sh
mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
op document get "nix-config sops age key" > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

Run that wherever the 1Password CLI is signed in, or copy the document's contents by hand.
