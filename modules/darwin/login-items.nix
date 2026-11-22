{ lib, ... }:
let
  # The apps that start at login. An app's own "open at login" setting is set only from the app,
  # so these are launchd agents instead. Each also starts its app at the switch that installs
  # it. Opening an app that runs already can show its window, so the agent opens the app only
  # when it is not running.
  apps = {
    amp = "/Applications/Amp.app";
    hex = "/Applications/Hex.app";
    thaw = "/Applications/Thaw.app";
    tinycast = "/Applications/Tinycast.app";
  };
in
{
  launchd.agents = lib.mapAttrs
    (_: app: {
      enable = true;
      config = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          ''[ -d "$0" ] && ! /usr/bin/pgrep -qf "^$0/Contents/MacOS/" && /usr/bin/open -g "$0"; exit 0''
          app
        ];
        RunAtLoad = true;
      };
    })
    apps;
}
