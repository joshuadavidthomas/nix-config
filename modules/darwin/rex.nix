# Rex for Mac on every Mac: the app, the `rex` command, its settings, and the netrc that Rex's
# flake input needs (docs/rex.md).
{ config, osConfig, lib, pkgs, vars, tailnetName, ... }:
let
  # Rex for Mac, a beta without a cask or a Nix package. Testers download it after a Discord
  # login; the app then updates itself (Sparkle) from this feed. A copy that this module
  # installs is named Rex.app; one from an older download is Rex Beta.app.
  rexFeed = "https://blob.superlogical.com/public/rex-app/preview-arm64/appcast.xml";
  rexTeam = "AG92C3PT77"; # Superlogical's Developer ID team
  rexApps = [ "/Applications/Rex.app" "/Applications/Rex Beta.app" ];

  # The Rex servers that the app connects to, over the tailnet. Each id is the app's own,
  # kept so that the app's records stay the same ones.
  server = name: id: icon:
    let url = "https://${name}.${vars.tailnet}:7297"; in
    { inherit id name icon; acceptsAnonymousClients = false; locators = [ url ]; preferredURL = url; };
  servers = [
    (server "lab-1" "043146D3-9A9C-483D-B914-C49878E127D5" "server.rack")
    (server "lab-2" "A5336183-E25A-4415-9539-3780DA0CBE19" "server.rack")
    (server "lab-3" "6CA718F4-E90C-403B-9701-E9EDDD3D92B4" "server.rack")
    (server "steamdeck" "FE35619C-F872-4330-82C2-42D24D022620" "desktopcomputer")
  ];
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

  # Install Rex for Mac when it is missing; afterwards it updates itself. The newest DMG in the
  # feed, used only if its app has a valid signature from Superlogical's team. A failed
  # download warns instead of failing the switch.
  home.activation.rexApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ${lib.concatMapStringsSep " && " (a: "[ ! -d ${lib.escapeShellArg a} ]") rexApps}; then
      noteEcho "Installing Rex for Mac"
      # each step exits on its own: set -e does not apply in a subshell that `if` tests
      if ! (
        tmp=$(mktemp -d) || exit 1
        trap '/usr/bin/hdiutil detach -quiet "$tmp/mnt" 2>/dev/null; rm -rf "$tmp"' EXIT
        # the feed lists the newest build first
        url=$(${lib.getExe pkgs.curl} -fsSL ${lib.escapeShellArg rexFeed} | grep -o 'url="[^"]*\.dmg"' | head -1 | cut -d'"' -f2)
        [ -n "$url" ] || exit 1
        ${lib.getExe pkgs.curl} -fsSL "$url" -o "$tmp/rex.dmg" || exit 1
        /usr/bin/hdiutil attach -quiet -nobrowse -readonly -mountpoint "$tmp/mnt" "$tmp/rex.dmg" || exit 1
        app="$tmp/mnt/Rex.app"
        /usr/bin/codesign --verify --deep --strict "$app" || exit 1
        /usr/bin/codesign -dv "$app" 2>&1 | grep -qx 'TeamIdentifier=${rexTeam}' || exit 1
        run /usr/bin/ditto "$app" /Applications/Rex.app || exit 1
      ); then
        warnEcho "Rex for Mac install failed; rerun the switch to retry"
      fi
    fi
  '';

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
