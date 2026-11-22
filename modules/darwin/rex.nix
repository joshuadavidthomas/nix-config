# Rex for Mac on every Mac: the app, the `rex` command, its settings, and the netrc that Rex's
# flake input needs (docs/rex.md).
{ config, osConfig, lib, pkgs, vars, tailnetName, ... }:
let
  # Rex for Mac, a beta without a cask or a Nix package; feed-apps.nix installs it. A copy from
  # an older download is Rex Beta.app.
  rexApps = [ "/Applications/Rex.app" "/Applications/Rex Beta.app" ];

  # The Rex servers that the app connects to, over the tailnet: every one but this Mac's own
  # (lib/rex-servers.nix).
  servers = map
    (s: { inherit (s) id name icon; acceptsAnonymousClients = false; locators = [ s.url ]; preferredURL = s.url; })
    (lib.filter (s: s.name != tailnetName) (import ../../lib/rex-servers.nix lib vars));
in
{
  # Rex's own terminals get `rex` on PATH; this puts it everywhere else
  home.packages = [
    (pkgs.writeShellScriptBin "rex" ''
      for app in ${lib.escapeShellArgs rexApps}; do
        bin="$app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
        if [ -x "$bin" ]; then exec "$bin" "$@"; fi
      done
      echo "rex: Rex for Mac is not installed; rebuild installs it" >&2
      exit 1
    '')
  ];

  # Rex's flake input needs pkgs.superlogical.com's login (docs/rex.md). opnix writes only the
  # token (modules/darwin/default.nix), so this agent writes the netrc line from it, at login and
  # each time opnix changes the token. Nix reads the netrc that netrc-file names, and
  # Determinate Nix names its own; this one, for you only, has no FlakeHub login, which nothing
  # here uses.
  xdg.configFile."nix/nix.conf".text = ''
    netrc-file = ${config.xdg.configHome}/nix/netrc
  '';
  launchd.agents.rex-netrc = {
    enable = true;
    config = let
      tokenFile = osConfig.services.onepassword-secrets.secretPaths.rexToken;
    in {
      ProgramArguments = [
        "${pkgs.writeShellScript "rex-netrc" ''
          set -eu
          netrc=${lib.escapeShellArg "${config.xdg.configHome}/nix/netrc"}
          [ -s "$1" ] || exit 0
          tmp=$(mktemp "$netrc.XXXXXX") # mktemp creates it 0600
          printf 'machine pkgs.superlogical.com login rex password %s\n' "$(cat "$1")" > "$tmp"
          mv "$tmp" "$netrc"
        ''}"
        tokenFile
      ];
      WatchPaths = [ tokenFile ];
      RunAtLoad = true;
    };
  };

  # The app's settings. targets.darwin.defaults writes only these keys (defaults import merges),
  # so the app's own state stays. The name of this Mac in Rex, and of its server on the
  # tailnet, come from the Mac's name on the tailnet (flake.nix).
  targets.darwin.defaults."com.superlogical.rex" = {
    "Workspace.activityGrouping" = "priority";
    "Workspace.activityGroupingResetToPriority" = true;
    "Workspace.balancesSplitsOnCreation" = false;
    "Workspace.darkThemeID" = "custom-654D1686-8B2D-4D3E-9F49-FC282458B71E"; # tokyonight_night
    "Workspace.lightThemeID" = "custom-08E0402F-BB46-4CFB-847A-77D92FA79A8A"; # tokyonight_day
    "Workspace.focusFollowsMouse" = false;
    "Workspace.inactivePaneFadeMode" = "both";
    "Workspace.interfaceStyle" = "blendTheme";
    "Workspace.paneDensity" = "comfortable";
    "Workspace.showsPaneHeaders" = true;
    "Workspace.sidebarPosition" = "left";
    "Workspace.tabIconTintMode" = "off";
    "Workspace.tabStyle" = "vertical";
    "Workspace.tabsFillAvailableSpace" = false;
    "Workspace.terminalFontName" = "MonoLisa Variable"; # from 1Password (modules/darwin)
    "Workspace.terminalFontPointSize" = 14.0;
    "Workspace.terminalFontSmoothing" = false;
    "Workspace.terminalPaddingColor" = "extend";
    "Workspace.usesStandardInactiveWindowPaneStyles" = true;
    "rex.agents.names-sessions" = true;
    "rex.client.label" = tailnetName;
    "rex.client.remoteControl" = true;
    "rex.server.automatic-restart-enabled" = true;
    "rex.server.block-plugin-reload-enabled" = false;
    "rex.server.run-mode" = "bundled";
    "rex.server.tailnet-enabled" = true;
    "rex.server.tailnet-hostname" = "${tailnetName}-rex";
    "rex.server.web-client-origin-patterns" = [ "https://rex.superlogical.com" ];
  };

  # The servers and the custom themes are JSON in data values, which targets.darwin.defaults
  # cannot write (rex-settings.py).
  home.activation.rexSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.python3} ${./rex-settings.py} \
      ${pkgs.writeText "rex-servers.json" (builtins.toJSON servers)} ${./rex-themes.json}
  '';
}
