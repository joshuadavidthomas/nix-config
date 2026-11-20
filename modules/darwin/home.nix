{ config, osConfig, lib, pkgs, inputs, vars, configName, ... }:
let
  # Rex for Mac, a beta without a cask or a Nix package. Testers download it after a Discord
  # login; the app then updates itself (Sparkle) from this feed. A copy that this step
  # installs is named Rex.app; one from an older download is Rex Beta.app.
  rexFeed = "https://blob.superlogical.com/public/rex-app/preview-arm64/appcast.xml";
  rexTeam = "AG92C3PT77"; # Superlogical's Developer ID team
  rexApps = [ "/Applications/Rex.app" "/Applications/Rex Beta.app" ];
in
{
  # Apply this Mac's configuration from ~/.nix-config, whatever macOS calls the Mac; extra arguments pass through
  # (e.g. `rebuild --rollback`). The first time, it copies the opnix token from 1Password
  # (modules/secrets.nix).
  home.packages = [
    # the yonder CLI, the release the lab boxes run (flake.lock, named in overlay.nix); reads
    # the fabric's coordinator from ~/.config/yonder/config (docs/yonder.md)
    pkgs.yonder
    pkgs.xcodegen # generates .xcodeproj files for iOS apps
    (pkgs.writeShellScriptBin "rebuild" ''
      if ! sudo test -s /etc/opnix-token; then
        if token=$(/usr/local/bin/op ${lib.escapeShellArgs vars.opnixTokenArgs}) && [ -n "$token" ]; then
          printf '%s\n' "$token" | sudo sh -c 'umask 077; cat > /etc/opnix-token'
          sudo launchctl kickstart -k system/org.nixos.opnix-secrets 2>/dev/null || true
        else
          echo "rebuild: couldn't read the opnix token from 1Password; secrets won't update" >&2
        fi
      fi
      # sudo leaves out your Nix config and so gh's GitHub token (home/nix.nix); root needs
      # the token to fetch private inputs (yonder)
      tokens=${lib.escapeShellArg "${config.xdg.configHome}/nix/access-tokens.conf"}
      if [ -r "$tokens" ]; then export NIX_CONFIG="$(cat "$tokens")"; fi
      exec sudo --preserve-env=NIX_CONFIG /run/current-system/sw/bin/darwin-rebuild switch --flake "$HOME/.nix-config#${configName}" "$@"
    '')
    # Rex's own terminals get `rex` on PATH; this puts it everywhere else
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

  home.sessionVariables.HOMEBREW_NO_ENV_HINTS = "1";

  # macOS's own man is used here (home-manager's default on darwin), so there are no
  # man-db caches to build; the fish module turns this on by default.
  programs.man.generateCaches = false;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.orbstack/ssh/config" ];
    settings."*".IdentityAgent =
      ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
    # The agent holds more keys than sshd's MaxAuthTries (6), so name the one the lab
    # trusts (modules/nixos/server.nix) instead of letting ssh offer them all.
    settings."lab-*" = {
      # the lab boxes' account, which can differ from this Mac's (flake.nix)
      User = (import ../../vars.nix).user;
      IdentityFile = "~/.ssh/lab.pub";
      IdentitiesOnly = "yes";
    };
    # yonder machines (`ssh dev.internal`): microVMs on the lab boxes, reached by name over
    # the tailnet. Their user is `agent`. Interim: every guest on a lab box trusts every
    # SSH_AUTHORIZED_KEY* in that box's /etc/yonder/secrets.env, which holds this key as
    # SSH_AUTHORIZED_KEY_MAC. When yonder passes keys per machine (yonder.dev
    # wiki/designs/amp-runner-auth.md), this stays the same; only which machines trust the
    # key changes.
    settings."*.internal" = {
      User = "agent";
      IdentityFile = "~/.ssh/lab.pub";
      IdentitiesOnly = "yes";
    };
  };
  home.file.".ssh/lab.pub".text = "${vars.keys.controller}\n";

  programs.git.signing.signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

  programs.ghostty = {
    enable = true;
    package = null; # installed by the Homebrew cask
    settings = {
      bold-is-bright = true;
      font-family = "MonoLisa";
      font-size = 14;

      keybind = [
        "ctrl+a>r=reload_config"
        "f11=toggle_fullscreen"

        "ctrl+a>enter=new_split:auto"
        "ctrl+a>\\=new_split:right"
        "ctrl+a>-=new_split:down"
        "ctrl+a>shift+h=new_split:left"
        "ctrl+a>shift+j=new_split:down"
        "ctrl+a>shift+k=new_split:up"
        "ctrl+a>shift+l=new_split:right"
        "ctrl+a>m=toggle_split_zoom"
        "ctrl+a>e=equalize_splits"
        "ctrl+alt+h=goto_split:left"
        "ctrl+alt+j=goto_split:bottom"
        "ctrl+alt+k=goto_split:top"
        "ctrl+alt+l=goto_split:right"

        "ctrl+a>c=new_tab"
        "ctrl+a>h=previous_tab"
        "ctrl+a>l=next_tab"
        "ctrl+a>comma=move_tab:-1"
        "ctrl+a>period=move_tab:1"

        "ctrl+a>1=goto_tab:1"
        "ctrl+a>2=goto_tab:2"
        "ctrl+a>3=goto_tab:3"
        "ctrl+a>4=goto_tab:4"
        "ctrl+a>5=goto_tab:5"
        "ctrl+a>6=goto_tab:6"
        "ctrl+a>7=goto_tab:7"
        "ctrl+a>8=goto_tab:8"
        "ctrl+a>9=goto_tab:9"

        "ctrl+a>w=close_surface"

        "shift+enter=text:\\n"
      ];

      mouse-hide-while-typing = true;
      mouse-scroll-multiplier = 2;

      background-opacity = 0.96;
      cursor-invert-fg-bg = true;
      resize-overlay-position = "top-left";
      theme = "dark:tokyonight_moon,light:tokyonight_day";
      unfocused-split-opacity = 0.75;
      window-padding-balance = true;
      window-padding-x = 0;
      window-padding-y = 0;
      window-theme = "ghostty";
    };
  };
  xdg.configFile."ghostty/themes/tokyonight_moon".source = "${inputs.tokyonight}/extras/ghostty/tokyonight_moon";
  xdg.configFile."ghostty/themes/tokyonight_day".source = "${inputs.tokyonight}/extras/ghostty/tokyonight_day";

  xdg.configFile."wezterm" = {
    source = ./wezterm;
    recursive = true;
  };
  xdg.configFile."wezterm/colors/tokyonight_storm.toml".source = "${inputs.tokyonight}/extras/wezterm/tokyonight_storm.toml";
}
