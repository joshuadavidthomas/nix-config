{ lib, ... }:
let
  # The macOS keyboard shortcuts that are off, by their ids in com.apple.symbolichotkeys.
  disabled = {
    "64" = "Show Spotlight search: Command-Space opens Tinycast (tinycast.nix)";
    "60" = "Select the previous input source: Control-Space";
    "61" = "Select next source in Input menu: Control-Option-Space";
  };
in
{
  # -dict-add changes only these shortcuts; activateSettings applies them without a logout.
  home.activation.keyboardShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatMapStrings (id: ''
      run /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
        -dict-add ${id} '<dict><key>enabled</key><false/></dict>'
    '') (lib.attrNames disabled)}
    run /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
