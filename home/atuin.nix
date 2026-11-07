# atuin, and its login to the sync server with the account in 1Password (modules/secrets.nix).
{ config, lib, osConfig, ... }:
let
  atuin = lib.getExe config.programs.atuin.package;

  # The login, with the account's files: a username, a password and a key. On the machines
  # NixOS and macOS configure, those files are the machine's (modules/secrets.nix); on the
  # Steam Deck (hosts/deck), where home-manager is standalone, they are in the home instead
  # (programs.onepassword-secrets, hosts/deck/default.nix). Config reads happen inside the
  # option values, not in a let here: the module argument is still being built when this
  # module is evaluated, so a top-level access of it recurses.
  loginScript = secrets:
    let
      secret = lib.mapAttrs (_: lib.escapeShellArg) secrets;
    in ''
      if [[ "$(${atuin} status 2>&1 || true)" == *"not logged in"* ]]; then
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
in
{
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = true;
      sync_address = "https://api.atuin.sh";
      enter_accept = true;
      keymap_mode = "vim-insert";
      # Nix decides the version; the release binaries (pkgs/atuin.nix) would check for updates
      update_check = false;
    };
  };

  home.activation.atuinLogin = lib.hm.dag.entryAfter [ "linkGeneration" ]
    # Log atuin in to sync wherever it isn't yet (fresh install, rebuilt machine), then pull
    # history down. Skipped once logged in.
    # `atuin status` exits 1 when logged out, so read its output first; under activation's
    # pipefail, piping it to grep would never match.
    (if osConfig != null
    then loginScript osConfig.services.onepassword-secrets.secretPaths
    else loginScript config.programs.onepassword-secrets.secretPaths);
}
