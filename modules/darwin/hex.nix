{ lib, pkgs, ... }:
let
  support = "$HOME/Library/Application Support/Hex";
in
{
  # Hex's settings, from the Mac mini (hex-settings.json): the switch merges them into the
  # settings file that Hex writes, so keys that are not in hex-settings.json stay as Hex set
  # them, such as its migrations and the microphone. Hex creates the file at its first launch;
  # until then there is nothing to merge into. Hex keeps its settings in memory, so a running Hex
  # is quit before a change and opened again after. Nothing changes, and Hex keeps running,
  # when all is already as configured.
  home.activation.hexSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${support}/settings.json"
    if [ -f "$settings" ]; then
      merged=$(${lib.getExe pkgs.jq} --slurpfile wanted ${./hex-settings.json} '. * $wanted[0]' "$settings")
      if [ "$merged" != "$(${lib.getExe pkgs.jq} . "$settings")" ]; then
        running=0
        if /usr/bin/pgrep -qf '^/Applications/Hex.app/Contents/MacOS/'; then
          running=1
          run /usr/bin/osascript -e 'quit app "Hex"'
          for _ in $(seq 50); do
            /usr/bin/pgrep -qf '^/Applications/Hex.app/Contents/MacOS/' || break
            sleep 0.2
          done
          # Hex wrote its own copy when it quit
          merged=$(${lib.getExe pkgs.jq} --slurpfile wanted ${./hex-settings.json} '. * $wanted[0]' "$settings")
        fi
        if [ -z "''${DRY_RUN:-}" ]; then
          printf '%s\n' "$merged" > "$settings.tmp" && mv "$settings.tmp" "$settings"
        fi
        noteEcho "hex: wrote its settings"
        if [ "$running" = 1 ]; then run /usr/bin/open -g /Applications/Hex.app; fi
      fi
    elif [ -d /Applications/Hex.app ]; then
      noteEcho "hex: open Hex and complete its onboarding, then run 'rebuild' again to apply its settings"
    fi
  '';
}
