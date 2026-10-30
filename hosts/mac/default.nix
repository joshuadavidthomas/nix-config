# Any Apple Silicon Mac; bootstrap.sh and `rebuild` use this, not the hostname.
{ config, lib, pkgs, vars, ... }: {
  # installs op to /usr/local/bin, the only place the 1Password app integration accepts
  programs._1password = {
    enable = true;
  };

  # xcodegen finds its setting presets at ../share/xcodegen next to the path it was run by,
  # without following symlinks, so the per-user profile must link that directory too.
  # Without it, generated projects have no base settings (empty PRODUCT_NAME).
  environment.pathsToLink = [ "/share/xcodegen" ];

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
      "abue-ammar/tinycast"
      "antoniorodr/memo"
      "steipete/tap"
      "yakitrak/yakitrak"
    ];
    # not in nixpkgs, or released too often to pin (like cf)
    brews = [
      "cloudflared" # the micro-hunter tunnel below; Cloudflare supports a release for about a year
      "antoniorodr/memo/memo" # Apple Notes
      "steipete/tap/gifgrep"
      "steipete/tap/remindctl" # Apple Reminders
      "steipete/tap/sag"
      "summarize"
      "yakitrak/yakitrak/notesmd-cli" # Obsidian; renamed from obsidian-cli upstream
    ];
    casks = [
      "1password" # updates itself; the first switch on a new Mac installs it
      "abue-ammar/tinycast/tinycast"
      "alt-tab"
      "ghostty"
      "jordanbaird-ice@beta" # until Thaw has replaced it
      "karabiner-elements"
      "linearmouse"
      "monitorcontrol"
      "omniwm"
      "orbstack"
      "steipete/tap/codexbar"
      "t3-code@nightly"
      "thaw" # replaces Ice
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
    # Xcode 26+ ships the Metal shader compiler as a separate download, which GPUI builds need.
    # A new Xcode can need it again. It's about 850 MB, so only fetch it when it's missing.
    if [ -d /Applications/Xcode.app ] && ! /usr/bin/xcodebuild -showComponent MetalToolchain 2>/dev/null | grep -q 'Status: installed'; then
      echo "downloading the Xcode Metal Toolchain..." >&2
      /usr/bin/xcodebuild -downloadComponent MetalToolchain || echo "warning: could not download the Metal Toolchain" >&2
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

  # micro-hunter's Reddit proxy and the Cloudflare Tunnel that the Worker reaches it through.
  # Boot services that run as vars.user, so a restart brings them back without a login. node
  # comes from Nix; cloudflared from Homebrew (brews above), so it stays current. The script and
  # its secrets (proxy.env, cookie.txt, tunnel-token) are still files in this directory.
  launchd.daemons =
    let
      dir = "${config.users.users.${vars.user}.home}/Library/Application Support/micro-hunter";
      service = log: args: {
        serviceConfig = {
          ProgramArguments = args;
          UserName = vars.user;
          GroupName = "staff";
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          StandardOutPath = "${dir}/${log}.log";
          StandardErrorPath = "${dir}/${log}.log";
        };
      };
    in
    {
      micro-hunter-reddit = service "proxy" [ "${pkgs.nodejs}/bin/node" "${dir}/reddit.mjs" ];
      micro-hunter-tunnel = service "tunnel" [
        "${config.homebrew.prefix}/bin/cloudflared" "tunnel" "--no-autoupdate" "run" "--token-file" "${dir}/tunnel-token"
      ];
    };

  home-manager.users.${vars.user}.imports = [ ./home.nix ];

  system.stateVersion = 6; # nix-darwin's value for new installs; never bump
}
