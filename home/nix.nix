# User-level Nix settings. GitHub access goes through gh's token so flake fetches aren't
# rate-limited (60 requests/hour anonymous) and private repos resolve. The token is written
# beside nix.conf at activation, never into the repo or /nix/store.
# One-time per machine: `gh auth login`.
{ config, lib, pkgs, ... }:
let
  tokensFile = "${config.xdg.configHome}/nix/access-tokens.conf";
in
{
  # The config itself, checked out where you edit it and switch from. The first switch on a
  # new machine runs straight from GitHub and leaves this clone behind.
  home.activation.nixConfigCheckout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.nix-config" ]; then
      run ${lib.getExe pkgs.git} clone https://github.com/joshuadavidthomas/nix-config "$HOME/.nix-config"
    fi
  '';

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
