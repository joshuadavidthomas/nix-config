# Declarative web-app shortcuts in Steam Game Mode (YouTube, Twitch, Disney+, Xbox Cloud Gaming).
# Replaces NonSteamLaunchers' browser-shortcut flow without a Decky plugin or a background scanner:
# a oneshot user unit merges only the shortcuts declared here into Steam's shortcuts.vdf before
# steam-launcher.service starts, and fetches any missing SteamGridDB artwork into config/grid/.
#
# Artwork is only downloaded for empty slots, so replacing an image in Game Mode (e.g. with
# decky-steamgriddb) sticks across rebuilds and reboots. Changes take effect at the next Steam
# start (reboot or restart Steam), matching steam-ac-suspend.service.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkWebApp =
    {
      name,
      url,
      steamGridDbId ? null,
      kiosk ? true,
      extraArgs ? [ ],
    }:
    let
      chromeFlags =
        [
          "run"
          "--branch=stable"
          "--arch=x86_64"
          "--command=/app/bin/chrome"
          "--file-forwarding"
          "com.google.Chrome"
          "@@u"
          "@@"
          "--window-size=1280,800"
          "--force-device-scale-factor=1.00"
          "--device-scale-factor=1.00"
          "--no-first-run"
          "--enable-features=OverlayScrollbar"
        ]
        ++ (if kiosk then [ "--kiosk" ] else [ "--start-fullscreen" ])
        ++ extraArgs
        ++ [ ''"${url}"'' ];
    in
    {
      inherit name steamGridDbId;
      # No --system/--user flag so `flatpak run` finds com.google.Chrome in either scope.
      exe = ''"/usr/bin/flatpak"'';
      startDir = ''"/usr/bin/"'';
      launchOptions = lib.concatStringsSep " " chromeFlags;
    };

  webApps = map mkWebApp [
    {
      name = "YouTube";
      url = "https://www.youtube.com";
      # SteamGridDB's autocomplete puts "YouTube VR" first; pin "YouTube (Website)".
      steamGridDbId = 36663;
    }
    {
      name = "Twitch";
      url = "https://www.twitch.tv";
      steamGridDbId = 5248358;
    }
    {
      name = "Disney+";
      url = "https://www.disneyplus.com";
      # Autocomplete drops '+' and returns Disney games; pin the streaming app entry.
      steamGridDbId = 5260961;
    }
    {
      name = "Xbox Cloud Gaming";
      url = "https://www.xbox.com/play";
      steamGridDbId = 5302079;
    }
  ];

  appsConfig = pkgs.writeText "steam-webapps.json" (
    builtins.toJSON {
      steamDir = "${config.xdg.dataHome}/Steam";
      fetchArtwork = true;
      apps = webApps;
    }
  );

  syncScript = pkgs.writeShellScript "steam-webapps-sync" ''
    exec ${pkgs.python3}/bin/python3 ${./steam-webapps.py} ${appsConfig} "$@"
  '';
in
{
  # Runs before each Steam start (like steam-ac-suspend): Steam holds shortcuts.vdf in memory and
  # rewrites it on exit, so syncing while Steam is down avoids races. Wants (not Requires) and a
  # bounded start timeout ensure a failure or offline boot never blocks Game Mode.
  systemd.user.services.steam-webapps = {
    Unit = {
      Description = "Sync declarative web-app shortcuts into Steam";
      Before = [ "steam-launcher.service" ];
    };
    Service = {
      Type = "oneshot";
      TimeoutStartSec = 30;
      ExecStart = "${syncScript}";
    };
    Install.WantedBy = [ "steam-launcher.service" ];
  };
}
