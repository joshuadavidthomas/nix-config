# Any Apple Silicon Mac; bootstrap.sh and `rebuild` use this, not the hostname.
{ config, lib, vars, ... }: {
  # installs op to /usr/local/bin, the only place the 1Password app integration accepts
  programs._1password = {
    enable = true;
  };

  # Homebrew stays reachable but after every Nix path, so it can't shadow Nix tools
  environment.systemPath = lib.mkAfter [
    "${config.homebrew.prefix}/bin"
    "${config.homebrew.prefix}/sbin"
    "${config.users.users.${vars.user}.home}/.lmstudio/bin" # lms, managed by LM Studio
  ];

  # GUI apps stay in Homebrew; Nix owns the CLI. Homebrew itself comes from its own installer
  # (bootstrap.sh) and updates itself; Nix only declares what it installs.
  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall"; # anything not declared here gets removed
    # declared here means trusted: Homebrew refuses formulae from untrusted third-party taps
    taps = map (name: { inherit name; trusted = true; }) [
      "antoniorodr/memo"
      "steipete/tap"
      "yakitrak/yakitrak"
    ];
    # not in nixpkgs
    brews = [
      "antoniorodr/memo/memo" # Apple Notes
      "steipete/tap/gifgrep"
      "steipete/tap/remindctl" # Apple Reminders
      "steipete/tap/sag"
      "summarize"
      "yakitrak/yakitrak/notesmd-cli" # Obsidian; renamed from obsidian-cli upstream
    ];
    casks = [
      "1password" # updates itself; the first switch on a new Mac installs it
      "ghostty"
      "jordanbaird-ice@beta"
      "orbstack"
      "steipete/tap/codexbar"
      "t3-code@nightly"
      "wezterm"
      "zed"
    ];
  };

  # Xcode asks again after every major update, and Homebrew refuses to run until it's
  # accepted. Runs before the Homebrew step.
  system.activationScripts.preActivation.text = ''
    if [ -d /Applications/Xcode.app ] && ! /usr/bin/xcodebuild -license check >/dev/null 2>&1; then
      echo "accepting the Xcode license..." >&2
      /usr/bin/xcodebuild -license accept || echo "warning: could not accept the Xcode license" >&2
    fi
  '';

  system.defaults.dock.autohide = true;

  # MonoLisa is licensed, so it's kept in 1Password, not in the repo. macOS ignores symlinked
  # fonts, so opnix writes the files straight into ~/Library/Fonts.
  # you read /etc/opnix-token to give it to a lab box at install (docs/new-lab-box.md)
  services.onepassword-secrets.users = [ vars.user ];

  services.onepassword-secrets.secrets =
    let
      font = item: file: {
        reference = "op://dotfiles/${item}/${file}";
        kind = "file";
        path = "${config.users.users.${vars.user}.home}/Library/Fonts/${file}";
        owner = vars.user;
        group = "staff";
        mode = "0644";
      };
    in
    {
      monolisaNormal = font "MonoLisa Normal" "MonoLisaNormal.ttf";
      monolisaItalic = font "MonoLisa Italic" "MonoLisaItalic.ttf";
      monolisaVariableNormal = font "MonoLisa Variable Normal" "MonoLisaVariableNormal.ttf";
      monolisaVariableItalic = font "MonoLisa Variable Italic" "MonoLisaVariableItalic.ttf";

      # pkgs.superlogical.com's token, for Rex's flake input: `nix flake check` and
      # `nix flake update` here fetch it (docs/rex.md). hosts/mac/home.nix makes it a netrc.
      rexToken = {
        reference = "op://dotfiles/Rex packages/password";
        path = "${config.users.users.${vars.user}.home}/Library/Application Support/opnix/rexToken";
        owner = vars.user;
        group = "staff";
      };
    };

  home-manager.users.${vars.user}.imports = [ ./home.nix ];

  system.stateVersion = 6; # nix-darwin's value for new installs; never bump
}
