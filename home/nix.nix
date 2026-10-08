# User-level Nix settings. GitHub access goes through gh's token so flake fetches aren't
# rate-limited and private repos (like this one, as a devenv input) resolve. The token is
# written beside nix.conf at activation, never into the repo or /nix/store.
# One-time per machine: `gh auth login`.
{ config, lib, pkgs, ... }:
let
  tokensFile = "${config.xdg.configHome}/nix/access-tokens.conf";
in
{
  # !include skips a missing file, so this is harmless before gh is logged in
  xdg.configFile."nix/nix.conf".text = ''
    !include access-tokens.conf
  '';

  home.activation.nixAccessTokens = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if token=$(${lib.getExe pkgs.gh} auth token 2>/dev/null) && [ -n "$token" ]; then
      if [[ ! -v DRY_RUN ]]; then
        tmp=$(mktemp "${tokensFile}.XXXXXX") # mktemp creates it 0600
        printf 'access-tokens = github.com=%s\n' "$token" > "$tmp"
        mv "$tmp" ${lib.escapeShellArg tokensFile}
      fi
      verboseEcho "Wrote GitHub access token for Nix"
    else
      warnEcho "gh isn't logged in; run 'gh auth login' so Nix can use its GitHub token"
    fi
  '';
}
