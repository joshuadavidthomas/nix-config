# atuin, and its login to the sync server with the account in secrets/secrets.yaml.
{ config, lib, pkgs, ... }:
let
  ageKeyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  secretsFile = ../../secrets/secrets.yaml;
  sops = lib.getExe pkgs.sops;
  atuin = lib.getExe config.programs.atuin.package;
in
{
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = true;
      sync_address = "https://api.atuin.sh";
      enter_accept = true;
      keymap_mode = "vim-insert";
    };
  };

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
}
