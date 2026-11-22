# Every Mac: the account, the apps and the secrets. hosts/<name>/mac.json has the Mac's
# account and the apps that were on it before Homebrew; hosts/<name>/default.nix, if there is
# one, adds what only that Mac has.
{ config, lib, pkgs, vars, configName, ... }:
let
  mac = lib.importJSON ../../hosts/${configName}/mac.json;
  # Apps that were on this Mac before the bootstrap, such as the ones an employer's IT installs
  # and manages. bootstrap.sh finds them. Homebrew leaves these casks out on this Mac, so it
  # does not install, adopt, update or remove the apps; the other Macs get them as usual.
  preinstalled = mac.preinstalledCasks or [ ];

  # the Mac apps, as Homebrew casks (homebrew below)
  casks = [
    "1password" # updates itself; the first switch on a new Mac installs it
    "abue-ammar/tinycast/tinycast"
    "alt-tab"
    "anomalyco/tap/hex"
    "ghostty"
    "helium-browser" # updates itself
    "jordanbaird-ice@beta" # until Thaw has replaced it
    "karabiner-elements"
    "linearmouse"
    "monitorcontrol"
    "microsoft-teams"
    "moonlight" # the stream client for the Deck's Sunshine (docs/sunshine.md)
    "omniwm"
    "orbstack"
    "steipete/tap/codexbar"
    "t3-code@nightly"
    "tailscale-app" # the standalone app; its own binary is the CLI (modules/darwin/tailscale.nix)
    "thaw" # replaces Ice
    "wezterm"
    "zed"
  ];
in
{
  # a name that is not in casks is a typo, and Homebrew would still manage that app
  assertions = map
    (name: {
      assertion = lib.elem name casks;
      message = "hosts/${configName}/mac.json: preinstalledCasks: ${name} is not a cask in modules/darwin/default.nix";
    })
    preinstalled;

  nix.enable = false; # Determinate Nix manages the daemon; nix-darwin must not
  system.primaryUser = vars.user; # required for user-level options (Homebrew, defaults)
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # knownUsers lets nix-darwin set the login shell. For the existing account (uid 501 on each Mac)
  # activation only updates UserShell and PrimaryGroupID (20, unchanged); nix-darwin
  # refuses to delete the primary user or any uid <= 501.
  users.knownUsers = [ vars.user ];
  users.users.${vars.user} = {
    uid = 501;
    home = "/Users/${vars.user}";
    shell = pkgs.fish;
  };

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
      "anomalyco/tap"
      "antoniorodr/memo"
      "getsentry/tools"
      "steipete/tap"
      "yakitrak/yakitrak"
    ];
    # not in nixpkgs, or released too often to pin (like cf)
    brews = [
      "antoniorodr/memo/memo" # Apple Notes
      "getsentry/tools/sentry-cli" # app dSYM uploads; nixpkgs still has 2.x, upstream is 3.x
      "mole" # Mac cleanup and disk analysis; nixpkgs' mole is a different tool
      "steipete/tap/gifgrep"
      "steipete/tap/remindctl" # Apple Reminders
      "steipete/tap/sag"
      "summarize"
      "yakitrak/yakitrak/notesmd-cli" # Obsidian; renamed from obsidian-cli upstream
    ];
    casks = lib.subtractLists preinstalled casks;
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
      # `nix flake update` here fetch it (docs/rex.md). home.nix makes it a netrc.
      rexToken = {
        reference = "op://dotfiles/Rex packages/password";
        path = "${config.users.users.${vars.user}.home}/Library/Application Support/opnix/rexToken";
        owner = vars.user;
        group = "staff";
      };
    }
    # The tokens of Tinycast's extensions (modules/darwin/tinycast.nix).
    // lib.mapAttrs
      (name: field: {
        reference = "op://dotfiles/Tinycast extensions/${field}";
        path = "${config.users.users.${vars.user}.home}/Library/Application Support/opnix/${name}";
        owner = vars.user;
        group = "staff";
      })
      {
        tinycastGithubToken = "github-token";
        tinycastKagiSessionLink = "kagi-session-link";
        tinycastKagiApiKey = "kagi-api-key";
      };

  home-manager.users.${vars.user}.imports = [ ./home.nix ];

  system.stateVersion = 6; # nix-darwin's value for new installs; never bump
}
