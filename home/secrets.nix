# Secrets live encrypted in ../secrets/ (sops + age; recipients in ../.sops.yaml). The one
# key that opens them is kept in 1Password and fetched on the first switch after 1Password
# is signed in; steps that need a secret decrypt it in memory, so nothing decrypted stays on
# disk (fonts excepted, which have to be real files).
#
# Edit secrets: sops secrets/secrets.yaml
{ config, lib, pkgs, ... }:
let
  cfg = config.secrets;
  ageKeyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  secretsFile = ../secrets/secrets.yaml;
  sops = lib.getExe pkgs.sops;
  atuin = lib.getExe config.programs.atuin.package;
in
{
  options.secrets = {
    op = lib.mkOption {
      type = lib.types.str;
      default = "/usr/local/bin/op"; # where nix-darwin's programs._1password puts it
      description = "1Password CLI used to fetch the age key; activation doesn't see your PATH.";
    };
    ageKeyDocument = lib.mkOption {
      type = lib.types.str;
      default = "nix-config sops age key";
      description = "Title of the 1Password document holding the age private key.";
    };
  };

  config = {
    home.packages = [ pkgs.age pkgs.sops ];
    home.sessionVariables.SOPS_AGE_KEY_FILE = ageKeyFile; # sops' macOS default is ~/Library

    # Fetch the age key from 1Password if this machine doesn't have it yet. Before 1Password
    # is installed and signed in this only warns; the next switch picks it up.
    home.activation.sopsAgeKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -s ${ageKeyFile} ]; then
        if [ -x ${lib.escapeShellArg cfg.op} ] && ${lib.escapeShellArg cfg.op} whoami >/dev/null 2>&1; then
          if [[ ! -v DRY_RUN ]]; then
            mkdir -p "$(dirname ${ageKeyFile})" && chmod 700 "$(dirname ${ageKeyFile})"
            tmp=$(mktemp "${ageKeyFile}.XXXXXX") # created 0600
            if ${lib.escapeShellArg cfg.op} document get ${lib.escapeShellArg cfg.ageKeyDocument} > "$tmp" \
                && grep -q '^AGE-SECRET-KEY-' "$tmp"; then
              mv "$tmp" ${ageKeyFile}
              verboseEcho "Fetched the sops age key from 1Password"
            else
              rm -f "$tmp"
              warnEcho "couldn't fetch '${cfg.ageKeyDocument}' from 1Password"
            fi
          fi
        else
          warnEcho "sign in to 1Password (and enable its CLI integration), then switch again to unlock secrets"
        fi
      fi
    '';

    # Log atuin in to sync wherever it isn't yet (fresh install, rebuilt machine), then pull
    # history down. Skipped once logged in.
    home.activation.atuinLogin = lib.hm.dag.entryAfter [ "linkGeneration" "sopsAgeKey" ] ''
      if ${atuin} status 2>&1 | grep -q "not logged in"; then
        (
          if [ ! -r ${ageKeyFile} ]; then
            exit 0 # sopsAgeKey already said what to do
          fi
          export SOPS_AGE_KEY_FILE=${ageKeyFile}
          secret() { ${sops} decrypt --extract "[\"atuin\"][\"$1\"]" ${secretsFile} 2>/dev/null; }

          password=$(secret password) || true
          if [ -z "$password" ]; then
            warnEcho "atuin: no password in secrets/secrets.yaml"
            exit 0
          fi

          if [[ -v DRY_RUN ]]; then
            echo "would log atuin in as $(secret username) and sync"
          elif ${atuin} login -u "$(secret username)" -p "$password" -k "$(secret key)"; then
            ${atuin} sync || warnEcho "atuin: logged in, but the first sync failed; run 'atuin sync'"
          else
            warnEcho "atuin: login failed (two-factor auth on the account, or a changed password?)"
          fi
        )
      fi
    '';
  };
}
