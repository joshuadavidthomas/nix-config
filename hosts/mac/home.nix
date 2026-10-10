{ lib, pkgs, inputs, vars, ... }: {
  # Apply ~/.nix-config, whatever this Mac is called; extra arguments pass through
  # (e.g. `rebuild --rollback`). The first time, it copies the opnix token from 1Password
  # (modules/secrets.nix).
  home.packages = [
    inputs.colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena # deploys the homelab
    (pkgs.writeShellScriptBin "rebuild" ''
      if ! sudo test -s /etc/opnix-token; then
        if token=$(/usr/local/bin/op read ${lib.escapeShellArg vars.opnixToken}) && [ -n "$token" ]; then
          printf '%s\n' "$token" | sudo sh -c 'umask 077; cat > /etc/opnix-token'
          sudo launchctl kickstart -k system/org.nixos.opnix-secrets 2>/dev/null || true
        else
          echo "rebuild: couldn't read the opnix token from 1Password; secrets won't update" >&2
        fi
      fi
      exec sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$HOME/.nix-config#mac" "$@"
    '')
  ];

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
      User = vars.user;
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
