{ config, lib, pkgs, ... }:
let
  app = "/Applications/Tinycast.app";
  # opnix writes these (modules/darwin/default.nix).
  secret = name: "${config.home.homeDirectory}/Library/Application Support/opnix/${name}";
  extensions = [
    "khasbilegt/1password"
    "josephschmitt/gif-search"
    "raycast/github"
    "fearoffish/kagi-search"
    "linear/linear"
    "jlrochin/mole"
    "marcjulian/obsidian"
    "maggie/xkcd"
  ];
in
{
  # Tinycast's settings, from the Mac mini. targets.darwin.defaults writes only these keys
  # (defaults import merges), so the app's own state stays. A hotkey is the JSON of a Carbon
  # key code and modifier mask: 49 is Space, 256 is Command, 4096 is Control.
  targets.darwin.defaults."com.abueammar.tinycast" = {
    "hotkey.togglePalette" = builtins.toJSON { combo._0 = { carbonKeyCode = 49; carbonModifiers = 256; }; };
    "hotkey.command:search-emoji" = builtins.toJSON { combo._0 = { carbonKeyCode = 49; carbonModifiers = 4352; }; };
    compactMode = false;
    dictationEnabled = false;
    dictationModel = "ultra";
    emojiSkinTone = "none";
    extensionsEnabled = true;
    favoriteApps = [ "com.superlogical.rex" ];
    fileSearchEnabled = true;
    hyperKeyIncludesShift = true;
    popToRootTimeout = 90;
    quicklinksEnabled = true;
    showFavoritesInCompactMode = true;
    showInMenuBar = false;
  };

  # Command-Space opens Tinycast, so Spotlight must not take it. 64 is "Show Spotlight search".
  # -dict-add changes only this shortcut; activateSettings applies it without a logout.
  home.activation.spotlightShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add 64 '<dict><key>enabled</key><false/></dict>'
    run /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  # The extensions, from the Raycast Store, as handle/name: the store's lookup key, the
  # manifest's owner or author. An install downloads the zip that the store built, the same as
  # Tinycast's own store install; Tinycast then updates them. The preferences are the ones that
  # differ from the extensions' defaults on the Mac mini, and the tokens come from 1Password
  # through opnix. Linear signs in with OAuth, in Tinycast. See tinycast-extensions.py.
  home.activation.tinycastExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d ${app} ]; then
      SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
        run ${lib.getExe pkgs.python3} ${./tinycast-extensions.py} ${pkgs.writeText "tinycast-extensions.json" (builtins.toJSON {
          inherit extensions;
          preferences = {
            "1password".version.string = "v8";
            github.application.string = "/Applications/Zed.app";
            github.baseClonePath.string = "${config.home.homeDirectory}/Code";
          };
          secrets = {
            github.personalAccessToken = secret "tinycastGithubToken";
            kagi-search.token = secret "tinycastKagiSessionLink";
            kagi-search.apiKey = secret "tinycastKagiApiKey";
          };
        })} \
        || warnEcho "tinycast: could not set up the extensions; run 'rebuild' again"
    fi
  '';

  # Start Tinycast at login, and at the switch that installs it. The app's own login item is
  # set only from its onboarding, so it is not declarative. Opening a running Tinycast shows
  # its window, so the agent opens it only when it is not running.
  launchd.agents.tinycast = {
    enable = true;
    config = {
      ProgramArguments = [ "/bin/sh" "-c" "[ -d ${app} ] && ! /usr/bin/pgrep -xq Tinycast && /usr/bin/open -g ${app}; exit 0" ];
      RunAtLoad = true;
    };
  };
}
