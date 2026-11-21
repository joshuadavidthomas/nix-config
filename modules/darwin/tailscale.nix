# Tailscale on every Mac: the standalone app (a cask in modules/darwin), logged in as you,
# like the Mac mini. bootstrap.sh logs a new Mac in; each switch then sets the settings below,
# so they stay as declared. The app's own binary is the CLI.
{ lib, pkgs, tailnetName, ... }:
let
  tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
in
{
  home.activation.tailscaleSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x ${tailscale} ] \
      && [ "$(${tailscale} status --json 2>/dev/null | ${lib.getExe pkgs.jq} -r .BackendState)" = Running ]; then
      run ${tailscale} set --hostname=${tailnetName} --accept-routes=true --accept-dns=true \
        || warnEcho "tailscale: could not set its settings; run 'rebuild' again"
    fi
  '';
}
