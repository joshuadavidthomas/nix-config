{ config, lib, pkgs, inputs, ... }:
let
  ageKeyFile = "${config.xdg.configHome}/sops/age/keys.txt";
in
{
  # MonoLisa is licensed, so the repo only carries it sops-encrypted. It's decrypted straight
  # into ~/Library/Fonts (macOS ignores symlinked fonts) and never enters /nix/store.
  home.activation.monolisa = lib.hm.dag.entryAfter [ "writeBoundary" "sopsAgeKey" ] ''
    if [ -r ${ageKeyFile} ]; then
      for font in MonoLisaNormal MonoLisaItalic; do
        tmp=$(mktemp)
        if SOPS_AGE_KEY_FILE=${ageKeyFile} ${lib.getExe pkgs.sops} decrypt --input-type json \
            --output-type binary ${../../secrets/fonts}/$font.ttf.json > "$tmp"; then
          cmp -s "$tmp" "$HOME/Library/Fonts/$font.ttf" \
            || run install -m 644 "$tmp" "$HOME/Library/Fonts/$font.ttf"
        else
          warnEcho "MonoLisa: couldn't decrypt $font"
        fi
        rm -f "$tmp"
      done
    fi # without the key, sopsAgeKey has already said what to do
  '';

  # Apply ~/.nix-config, whatever this Mac is called; extra arguments pass through
  # (e.g. `rebuild --rollback`).
  home.packages = [
    (pkgs.writeShellScriptBin "rebuild" ''
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
  };

  programs.git = {
    settings.user.email = "josh@joshthomas.dev";
    signing.signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  };

  programs.jujutsu.settings.user.email = "josh@joshthomas.dev";

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
