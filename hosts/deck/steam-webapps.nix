# Declarative streaming/web-app shortcuts in Steam Game Mode (YouTube via VacuumTube, plus
# Twitch, Disney+, and Xbox Cloud Gaming via Flatpak Chrome).
# Replaces NonSteamLaunchers' shortcut flow without a Decky plugin or a background scanner:
# a oneshot user unit merges only the shortcuts declared here into Steam's shortcuts.vdf before
# steam-launcher.service starts, fetches missing SteamGridDB artwork into config/grid/, sets
# ResolutionOverride = Native in localconfig.vdf, and wires Steam Input templates for browser
# apps across all controller types.
#
# Artwork is only downloaded for empty slots, and controller/resolution overrides are only
# written when unset or Nix-managed, so customizations made in Game Mode stick across rebuilds
# and reboots. Changes take effect at the next Steam start (reboot or restart Steam).
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
      controllerLayout ? null, # "tv" (arrow keys/Enter/Esc), "browser" (mouse/scroll), or null (Gamepad)
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
          "--force-device-scale-factor=1.00"
          "--device-scale-factor=1.00"
          "--start-maximized"
          "--no-first-run"
          "--enable-features=OverlayScrollbar"
        ]
        ++ (if kiosk then [ "--kiosk" ] else [ "--start-fullscreen" ])
        ++ extraArgs
        ++ [ ''"${url}"'' ];
    in
    {
      inherit name steamGridDbId controllerLayout;
      # No --system/--user flag so `flatpak run` finds com.google.Chrome in either scope.
      exe = ''"/usr/bin/flatpak"'';
      startDir = ''"/usr/bin/"'';
      launchOptions = lib.concatStringsSep " " chromeFlags;
      # Ask Steam/Gamescope to run the app at the connected display's native resolution
      # (instead of Steam's 1280x720 non-Steam default).
      resolutionOverride = "Native";
    };

  mkFlatpakApp =
    {
      name,
      appId,
      command ? null,
      steamGridDbId ? null,
      controllerLayout ? null,
      extraArgs ? [ ],
    }:
    let
      flags =
        [
          "run"
          "--branch=stable"
          "--arch=x86_64"
        ]
        ++ lib.optionals (command != null) [ "--command=${command}" ]
        ++ [
          "--file-forwarding"
          appId
          "@@u"
          "@@"
        ]
        ++ extraArgs;
    in
    {
      inherit name steamGridDbId controllerLayout;
      exe = ''"/usr/bin/flatpak"'';
      startDir = ''"/usr/bin/"'';
      launchOptions = lib.concatStringsSep " " flags;
      resolutionOverride = "Native";
    };

  webApps = [
    # VacuumTube wraps YouTube Leanback cleanly (no UA-spoofing deprecation banner or low-res
    # thumbnails, native gamepad support, built-in adblock/SponsorBlock).
    (mkFlatpakApp {
      name = "YouTube";
      appId = "rocks.shy.VacuumTube";
      command = "startvacuumtube";
      extraArgs = [ "--fullscreen" ];
      controllerLayout = null;
      # SteamGridDB's autocomplete puts "YouTube VR" first; pin "YouTube (Website)".
      steamGridDbId = 36663;
    })
    (mkWebApp {
      name = "Twitch";
      url = "https://www.twitch.tv";
      controllerLayout = "browser";
      steamGridDbId = 5248358;
    })
    (mkWebApp {
      name = "Disney+";
      url = "https://www.disneyplus.com";
      controllerLayout = "browser";
      # Autocomplete drops '+' and returns Disney games; pin the streaming app entry.
      steamGridDbId = 5260961;
    })
    (mkWebApp {
      name = "Xbox Cloud Gaming";
      url = "https://www.xbox.com/play";
      # Leaves Steam's default Gamepad layout untouched for xCloud games.
      controllerLayout = null;
      steamGridDbId = 5302079;
    })
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
