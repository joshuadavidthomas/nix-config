# Secrets live encrypted in ../secrets/secrets.yaml (sops + age; recipients in
# ../.sops.yaml). Each machine needs the age key from 1Password at ~/.config/sops/age/keys.txt.
# Steps here decrypt in memory when they need a value; nothing decrypted stays on disk.
#
# Edit secrets: sops secrets/secrets.yaml
{ config, lib, pkgs, ... }:
let
  ageKeyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  secretsFile = ../secrets/secrets.yaml;
  sops = lib.getExe pkgs.sops;
  atuin = lib.getExe config.programs.atuin.package;
in
{
  home.packages = [ pkgs.age pkgs.sops ];
  home.sessionVariables.SOPS_AGE_KEY_FILE = ageKeyFile; # sops' macOS default is ~/Library

  # Log atuin in to sync wherever it isn't yet (fresh install, rebuilt machine), then pull
  # history down. Skipped once logged in.
  home.activation.atuinLogin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if ${atuin} status 2>&1 | grep -q "not logged in"; then
      (
        if [ ! -r ${ageKeyFile} ]; then
          warnEcho "atuin: no age key at ${ageKeyFile}; copy it from 1Password and switch again"
          exit 0
        fi
        export SOPS_AGE_KEY_FILE=${ageKeyFile}
        secret() { ${sops} decrypt --extract "[\"atuin\"][\"$1\"]" ${secretsFile} 2>/dev/null; }

        password=$(secret password) || true
        if [ -z "$password" ]; then
          warnEcho "atuin: no password in secrets/secrets.yaml yet; see home/secrets.nix"
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
}
