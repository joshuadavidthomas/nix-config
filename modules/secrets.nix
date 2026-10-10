# Every machine reads its secrets from the dotfiles vault in 1Password. opnix fetches them
# with the service account token in /etc/opnix-token, which is put on each machine by hand
# (docs/secrets.md), and writes each secret to a file. It runs as a system service (systemd on
# NixOS, launchd on macOS) when its secrets change and at boot, not inside a switch. Its
# home-manager module isn't used: on a machine without a token, it ends the whole
# home-manager activation early.
# hosts/ and modules/ add the secrets that only some machines need.
{ config, lib, pkgs, vars, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
  home = config.users.users.${vars.user}.home;

  # A secret that only vars.user can read. On macOS, users can't enter opnix's own directory,
  # so these go in the user's Library there.
  userSecret = name: reference: {
    inherit reference;
    owner = vars.user;
    group = if isDarwin then "staff" else "users";
    path = if isDarwin then "${home}/Library/Application Support/opnix/${name}" else null;
  };
in
{
  services.onepassword-secrets = {
    enable = true;
    # home/atuin.nix reads these through osConfig.services.onepassword-secrets.secretPaths
    secrets = lib.mapAttrs userSecret {
      atuinUsername = "op://dotfiles/Atuin/username";
      atuinPassword = "op://dotfiles/Atuin/password";
      atuinKey = "op://dotfiles/Atuin/key";
    };
  };
}
