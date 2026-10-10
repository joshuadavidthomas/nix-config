# atuin, and its login to the sync server with the account in 1Password (modules/secrets.nix).
{ config, lib, osConfig, ... }:
let
  atuin = lib.getExe config.programs.atuin.package;
  secret = lib.mapAttrs (_: lib.escapeShellArg) osConfig.services.onepassword-secrets.secretPaths;
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
  home.activation.atuinLogin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if ${atuin} status 2>&1 | grep -q "not logged in"; then
      if [ ! -r ${secret.atuinPassword} ]; then
        warnEcho "atuin: opnix hasn't fetched the account from 1Password yet (docs/secrets.md); switch again when it has"
      elif [[ -v DRY_RUN ]]; then
        echo "would log atuin in as $(cat ${secret.atuinUsername}) and sync"
      elif ${atuin} login -u "$(cat ${secret.atuinUsername})" -p "$(cat ${secret.atuinPassword})" \
          -k "$(cat ${secret.atuinKey})"; then
        ${atuin} sync || warnEcho "atuin: logged in, but the first sync failed; run 'atuin sync'"
      else
        warnEcho "atuin: login failed (two-factor auth on the account, or a changed password?)"
      fi
    fi
  '';
}
