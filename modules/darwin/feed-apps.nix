{ lib, pkgs, ... }:
let
  install = pkgs.writeShellApplication {
    name = "install-feed-app";
    runtimeInputs = with pkgs; [ coreutils curl gnugrep gnused openssl ];
    text = builtins.readFile ./install-feed-app.sh;
  };

  # Mac apps without a Homebrew cask. Each updates itself from its feed; the switch installs it
  # from there when it is missing (install-feed-app.sh). `present` lists the copies that count
  # as installed. team is the developer's Apple team, which signs the app.
  apps = {
    # Rex for Mac, a beta for testers (docs/rex.md). A copy from an older download is Rex Beta.app.
    "Rex for Mac" = {
      kind = "sparkle";
      feed = "https://blob.superlogical.com/public/rex-app/preview-arm64/appcast.xml";
      team = "AG92C3PT77";
      app = "Rex.app";
      present = [ "/Applications/Rex.app" "/Applications/Rex Beta.app" ];
    };
    Amp = {
      kind = "sparkle";
      feed = "https://static.ampcode.com/mac/appcast.xml";
      team = "PZT9BJUAA5";
      app = "Amp.app";
      present = [ "/Applications/Amp.app" ];
    };
    "Fastmail Beta" = {
      kind = "electron";
      feed = "https://dl.fastmailcdn.com/desktop/beta/mac/arm64/beta-mac.yml";
      team = "XWGA7UXNF3";
      app = "Fastmail Beta.app";
      present = [ "/Applications/Fastmail Beta.app" ];
    };
  };
in
{
  # A failed download warns instead of failing the switch.
  home.activation.feedApps = lib.hm.dag.entryAfter [ "writeBoundary" ] (lib.concatStrings (lib.mapAttrsToList
    (name: a: ''
      if ${lib.concatMapStringsSep " && " (p: "[ ! -d ${lib.escapeShellArg p} ]") a.present}; then
        noteEcho ${lib.escapeShellArg "Installing ${name}"}
        run ${lib.getExe install} ${lib.escapeShellArgs [ a.kind a.feed a.team a.app (lib.head a.present) ]} \
          || warnEcho ${lib.escapeShellArg "${name} install failed; rerun the switch to retry"}
      fi
    '')
    apps));
}
