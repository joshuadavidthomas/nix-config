{ lib, ... }:
let
  app = "/Applications/Tinycast.app";
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
