# The Steam Deck. SteamOS owns the operating system and updates itself (A/B images), so this
# is a plain home-manager module, built as homeConfigurations.deck. The user is SteamOS's own
# `deck` (uid 1000), not `josh`: the Steam session and Valve's update tooling expect it.
# One hard rule: the login shell stays bash, and fish is started by hand. SteamOS updates
# reset /etc/shells, and a login shell that is not in it keeps both the desktop session and
# SSH from logging in (SteamOS issue #2922).
{
  config,
  lib,
  pkgs,
  inputs,
  vars,
  ...
}: let
  # The Rex package the flake input pins (the same build the lab boxes run, from the
  # snapshot pinned in flake.lock). Evaluating this fetches pkgs.superlogical.com with the
  # netrc below, so an apply after a token change needs the fetch to succeed.
  rex = inputs.rex.packages.${pkgs.stdenv.hostPlatform.system}.rex;
  # The tailnet side uses the deck's own tailscaled (SteamOS keeps its binary under
  # /opt/tailscale, on the home partition); the CLI that talks to it is that daemon's own
  # build, so the two cannot drift.
  tailscale = "/opt/tailscale/tailscale";

  # Sunshine's two helpers (docs/sunshine.md). Both run as deck, in the runtime dir
  # systemd gives the unit; they discover the compositor socket by name because the two
  # sessions name it differently — Plasma is wayland-0, the gamescope Game Mode session is
  # gamescope-0 — and sunshine needs WAYLAND_DISPLAY named, not guessed.
  sunshineWait = pkgs.writeShellScript "deck-sunshine-wait" ''
    # The plugin waited for a display (drm_info), a connected screen. This waits one step
    # further, for the screen a capture can hold: an existing compositor socket in the
    # runtime dir. A boot with no session — cold start, suspended before resume — fails
    # here at 60s and the unit retries on-failure, so it settles as soon as the first
    # session opens. That is the cold-reboot shape groundbreaking happens in at test time.
    runtime="''${XDG_RUNTIME_DIR:-/run/user/1000}"
    shopt -s nullglob
    for i in $(seq 1 60); do
      for s in "$runtime"/wayland-* "$runtime"/gamescope-0; do
        [ -S "$s" ] && exit 0
      done
      sleep 1
    done
    echo "no compositor socket in $runtime after 60s" >&2
    exit 1
  '';
  sunshineLaunch = pkgs.writeShellScript "deck-sunshine-launch" ''
    runtime=''${XDG_RUNTIME_DIR:-/run/user/1000}
    export XDG_RUNTIME_DIR="$runtime"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
    shopt -s nullglob
    # wayland-* first: Plasma holds the session when both could exist at a switch-over;
    # in Game Mode alone, only gamescope-0 carries the session.
    for s in "$runtime"/wayland-* "$runtime"/gamescope-0; do
      export WAYLAND_DISPLAY="$(basename "$s")"
      break
    done
    exec ${pkgs.sunshine}/bin/sunshine
  '';

  # Steam's idle suspend on AC power, set to Never before Steam starts (docs/new-deck.md,
  # Staying on while docked). 0 is the value Steam itself writes for Never. Steam keeps its
  # settings in memory and rewrites config.vdf while it runs, so only a write before the
  # start holds. A missing file or a key that is not there exactly once fails the unit:
  # Steam then starts with its own value, and the Deck suspends on its own timeout.
  steamAcSuspend = pkgs.writeShellScript "steam-ac-suspend" ''
    set -euo pipefail
    vdf=${lib.escapeShellArg "${config.xdg.dataHome}/Steam/config/config.vdf"}
    key='"IdleSuspendACSeconds"'
    if [ ! -f "$vdf" ]; then
      echo "no $vdf yet; Steam writes it on its first save" >&2
      exit 1
    fi
    count=$(${pkgs.gnugrep}/bin/grep -c "^[[:space:]]*$key[[:space:]]" "$vdf" || true)
    if [ "$count" != 1 ]; then
      echo "$key is in $vdf $count times, not once; Steam's config has changed shape" >&2
      exit 1
    fi
    ${pkgs.gnused}/bin/sed -i -E "s/^([[:space:]]*$key[[:space:]]+)\"[^\"]*\"/\1\"0\"/" "$vdf"
  '';
in {
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  # home-manager's own module for a machine where Nix does not manage the OS: it fills in
  # XDG paths and such, the same way it does on WSL.
  targets.genericLinux.enable = true;

  # Sunshine (docs/sunshine.md): the stream host as a repo-owned package, in place of the
  # decky-sunshine plugin and the system Flatpak it launched. The launch is the
  # deck-sunshine unit below; the web UI's login is provisioned by hand once the 1Password
  # item exists (docs/sunshine.md#provision), and its capture finding gets written into
  # ~/.config/sunshine only after the first run proves the defaults.
  home.packages = [
    pkgs.sunshine
    # The Deck builds and applies itself from GitHub, like a lab box (docs/changes.md): one
    # command for both halves of an apply. Only commits reach it.
    (pkgs.writeShellScriptBin "rebuild" ''
      # rebuild [ACTION [REF]]: ACTION is home-manager's (switch, build...), REF a branch, tag
      # or commit of the repo on GitHub. --refresh: a branch moves, so don't use a cached copy.
      set -e
      action=''${1:-switch}
      home-manager "$action" --refresh \
        --flake "github:joshuadavidthomas/nix-config?ref=''${2:-main}#deck"
      # After a switch, the half home-manager cannot do: steamos-etc installs /etc and its
      # units, and asks for sudo only when /etc changed. The profile's copy is the new
      # generation's; this script's own store path belongs to the old one.
      if [ "$action" = switch ]; then
        exec "$HOME/.nix-profile/bin/steamos-etc"
      fi
    '')
  ];

  imports = [
    # Secrets, read with the service account's token. On the machines NixOS and macOS
    # configure, opnix runs as a system service; the Deck has neither, so its secrets come in
    # at the home-manager level instead (Stage 2, docs/new-deck.md). Its module skips the
    # fetch with a warning while the token is missing, so the first apply does not fail.
    inputs.opnix.homeManagerModules.default
    # Declarative /etc files and system services, for the keep-list, Rex's login server and
    # the SteamOS update-hang workaround (Stage 2, docs/new-deck.md).
    inputs.steamos-etc.homeManagerModules.default
    # Declarative web-app shortcuts in Steam Game Mode (YouTube, Twitch, Disney+, Xbox Cloud Gaming).
    ./steam-webapps.nix
  ];

  programs.onepassword-secrets = {
    enable = true;
    # The token stays in the home, not /etc/opnix-token: an update drops what is in /etc, and
    # the home needs no sudo to read. Placed once by hand from the Mac's own token
    # (docs/new-deck.md), the same way a lab box gets its token at install.
    tokenFile = "${config.home.homeDirectory}/.config/opnix/token";
    secrets = {
      # atuin's login to the sync server (home/atuin.nix reads these; same item as
      # modules/secrets.nix on the other machines). group is deck's own: SteamOS has no
      # `users` group for it, and opnix's chown to the home group needs no root.
      atuinUsername.reference = "op://dotfiles/Atuin/username";
      atuinUsername.path = ".config/opnix/atuinUsername";
      atuinUsername.group = "deck";
      atuinPassword.reference = "op://dotfiles/Atuin/password";
      atuinPassword.path = ".config/opnix/atuinPassword";
      atuinPassword.group = "deck";
      atuinKey.reference = "op://dotfiles/Atuin/key";
      atuinKey.path = ".config/opnix/atuinKey";
      atuinKey.group = "deck";
      # Nix's login for the rex flake input (docs/rex.md), written to the netrc below
      rexToken.reference = "op://dotfiles/Rex packages/password";
      rexToken.path = ".config/opnix/rexToken";
      rexToken.group = "deck";
      # commits sign with the lab boxes' shared key (docs/decisions.md#git-signing); the Mac
      # signs through 1Password's own signer, the Deck has neither app nor agent, so the file
      gitSigningKey = {
        reference = "op://dotfiles/Lab signing key/private key?ssh-format=openssh";
        path = ".config/opnix/gitSigningKey";
        group = "deck";
      };
    };
  };

  home.activation.rexNetrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Nix reads this netrc when it fetches the rex flake input (docs/rex.md). Same file and
    # same line as the Mac's (modules/darwin/home.nix) and a lab box's (nix-credentials in
    # modules/nixos/server.nix); never in the store, never in the repo. Without it, the next
    # home-manager switch fails at evaluation, before this runs, so the first one after a
    # fresh install needs the token placed first (docs/new-deck.md).
    netrc=${lib.escapeShellArg "${config.home.homeDirectory}/.config/nix/netrc"}
    token=${config.programs.onepassword-secrets.secretPaths.rexToken}
    if [ -s "$token" ] || [[ -v DRY_RUN ]]; then
      tmp=$(mktemp "$netrc.XXXXXX") # mktemp creates it 0600
      printf 'machine pkgs.superlogical.com login rex password %s\n' "$(cat "$token")" > "$tmp"
      mv "$tmp" "$netrc"
    else
      warnEcho "rex netrc: opnix has no Rex packages token yet (docs/secrets.md)"
    fi
  '';

  # Standalone home-manager prints a count of unread news items at every switch; the deck is
  # the one machine that runs it standalone.
  news.display = "silent";

  # Commits sign with the key opnix wrote (home/git.nix sets its default). Signing's own
  # config lives in 1Password for the Mac; the Deck names the file opnix wrote.
  programs.git.signing.key = config.programs.onepassword-secrets.secretPaths.gitSigningKey;

  # The docked Deck stays awake because Steam never starts an idle suspend on AC power
  # (docs/decisions.md). A user unit, because Steam is one: SteamOS starts it as
  # steam-launcher.service in the deck's session. Oneshot without RemainAfterExit, so it
  # runs again before every Steam start, and Wants (not Requires), so a failure here never
  # keeps Game Mode from coming up.
  systemd.user.services.steam-ac-suspend = {
    Unit = {
      Description = "Set Steam's idle suspend on AC power to Never";
      Before = [ "steam-launcher.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${steamAcSuspend}";
    };
    Install.WantedBy = [ "steam-launcher.service" ];
  };

  programs.steamos-etc = {
      enable = true;
      # Hold the user session until /nix is mounted, so home-manager's links resolve at login
      waitForNix = true;

      # Sunshine needs a GL/Vulkan stack that Nix-built programs can find, the way NixOS
      # mounts its own: /run/opengl-driver with GBM, the radeonsi VA-API driver and Vulkan
      # ICDs, built from this repo's pinned nixpkgs (docs/sunshine.md, finding two). The
      # module's own option owns the tmpfiles rule and its keep-list entry; without it,
      # HM's absorbed targets.genericLinux check nags for a sudo non-nixos-gpu-setup at
      # every nixpkgs bump, and the file's role in /etc would die with the next update.
      gpuDrivers = true;

      # Rex's flake input needs pkgs.superlogical.com's login (docs/rex.md), and Nix finds it
      # through netrc-file. The line lives here, in the file the installer's nix.conf
      # includes, not in ~/.config/nix/nix.conf: the client sends a user-level setting on to
      # the daemon, which refuses a restricted one from a user it does not trust and warns
      # at every command. A system-level one stays with the client. The daemon reads it too
      # and needs nothing from it: only the flake input is behind the login. The deck is not
      # a trusted user, so the daemon stays out of its reach without sudo's password.
      files."nix/nix.custom.conf" = ''
        netrc-file = ${config.xdg.configHome}/nix/netrc
      '';

      # The login server's policy, the same file the lab boxes build in the Rex module
      # (services.rex.loginServer on lab-1): the owner's Tailscale login acts as the deck
      # account, which the Steam session and Valve's tooling own.
      files."rex/accounts.jsonc" = builtins.toJSON {
        version = 1;
        accounts.deck.principals = [ vars.tailscaleLogin ];
        defaults.${vars.tailscaleLogin} = "deck";
      };

      # The login server runs with --pam=false on the deck. SteamOS's PAM modules dlopen
      # libraries (libsystemd lives off the loader path on this image, libcrypt.so.2 is
      # absent) that a prebuilt binary cannot reach, and rex knows this case: without PAM it
      # does shadow-based account checks instead (its container mode). The account exists, so
      # the identity mapped above admits the caller. The NixOS machines get their PAM policy
      # from the NixOS module (lab-1's /etc/pam.d/rex-login-server) and keep it. An earlier
      # attempt installed a hand-written /etc/pam.d/rex-login-server; leaving it undeclared
      # removes it on the next apply.

      # Rex's login server, the lab boxes' shape brought to SteamOS (docs/rex.md): one root
      # process that asks the deck's own tailscaled who each caller is, maps them to the
      # `deck` account, and listens through Tailscale Serve, in HTTPS on Rex's port, so Rex
      # for Mac and Rex for iOS open sessions on the deck like they do on lab-1.
      # The attrset key is the unit file's name: keep the lab boxes' snake-case shape, which
      # this unit's Requires and After also name.
      services = {
        "rex-login-server" = {
          Unit = {
            Description = "Rex Login Server";
            Documentation = [ "https://superlogical.com" ];
            After = [ "network-online.target" "tailscaled.service" ];
            Wants = [ "network-online.target" ];
            Requires = [ "tailscaled.service" ];
          };
          Service = {
            Type = "notify-reload";
            NotifyAccess = "main";
            KillMode = "process";
            Restart = "on-failure";
            RestartSec = "5s";
            RuntimeDirectory = "rex";
            RuntimeDirectoryPreserve = "yes";
            Environment = [
              "TERMINFO_DIRS=${rex}/share/terminfo:"
              "TZDIR=${pkgs.tzdata}/share/zoneinfo"
            ];
            ExecStart = lib.escapeShellArgs [
              "${rex}/bin/rex" "login-server"
              "--listen" "unix:///run/rex/login-server.sock"
              "--accounts" "/etc/rex/accounts.jsonc"
              "--runtime-root" "/run/rex"
              "--log-format" "text"
              "--pam=false"
              "--extra-listen" "tailnet-serve:///run/rex/serve.sock"
            ];
          };
          Install.WantedBy = [ "multi-user.target" ];
        };

        # Tailscale Serve's mapping, the module's rex-tailscale-serve.service verbatim, run
        # against the deck's tailscaled by its own CLI: at boot `serve --bg` maps HTTPS 7297
        # to the login server's Serve socket, and on stop it takes the mapping off.
        "rex-tailscale-serve" = {
          Unit = {
            Description = "Rex Tailscale Serve";
            After = [ "tailscaled.service" "rex-login-server.service" ];
            Requires = [ "tailscaled.service" "rex-login-server.service" ];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = 5;
            ExecStartPre = lib.escapeShellArgs [ tailscale "wait" ];
            ExecStart = lib.escapeShellArgs [ tailscale "serve" "--bg" "--https=7297" "unix:/run/rex/serve.sock" ];
            ExecStop = lib.escapeShellArgs [ tailscale "serve" "--https=7297" "off" ];
          };
          Install.WantedBy = [ "multi-user.target" ];
        };

        # Sunshine (docs/sunshine.md): the stream host as a repo service, where the decky
        # plugin and the system Flatpak it launched were. Runs as root, because Sunshine's
        # privilege model re-escalates at every stream start (a capability-only run cannot
        # do that) — its config, state and credentials stay deck-Home through
        # XDG_CONFIG_HOME (/home/deck/.config), and the devices it touches already carry
        # deck-write ACLs. The capture method is the conf's capture = portal.
        # The web UI's login is not this unit's business: it is provisioned once by hand
        # from the 1Password item (docs/sunshine.md#provision), the way atuin's login was.
        # Ports to arrive later: the system Flatpak still holds 47984-48010 until it is
        # retired, so this unit and it cannot run at the same time.
        "deck-sunshine" = {
          Unit = {
            Description = "Sunshine game stream host";
            Documentation = [ "https://docs.lizardbyte.dev/projects/sunshine" ];
            Wants = [ "graphical.target" ];
            After = [ "graphical.target" ];
          };
          Service = {
            Type = "simple";
            # Sunshine's privilege model is "elevated at boot, drop after it, re-escalate at
            # every stream start" (has_elevated_privileges gates the portal's probe with a
            # dummy, and re-enumeration happens after the encoder test). AmbientCapabilities
            # served the boot probe and broke every post-boot stream: a dropped ambient cap
            # cannot be re-acquired, so stream starts died with "Failed to gain
            # CAP_SYS_ADMIN" under every encoder (2026-11-09, 15:52). So the process runs as
            # root, and everything it keeps lives in the deck's home through XDG_CONFIG_HOME
            # and the runtime of deck's session (docs/sunshine.md).
            Environment = [
              "XDG_CONFIG_HOME=/home/deck/.config"
              "XDG_RUNTIME_DIR=/run/user/1000"
            ];
            ExecStartPre = "${sunshineWait}";
            ExecStart = "${sunshineLaunch}";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "graphical.target" ];
        };

        # SteamOS issue #2957: an update freezes /var, then blocks forever on its first
        # lookup of /etc/atomic-update.conf.d, because the last update's rsync dropped the
        # OverlayFS xattr that the lookup would write back. A lookup once per boot, while
        # /var is writable, sets the xattr so the frozen-time lookup has nothing to write.
        # The default keep list carries the unit and its enablement to each new slot, and
        # Valve's own fix in holo-sync-var makes this unnecessary.
        "atomic-update-conf-prime" = {
          Unit = {
            Description = "Pre-resolve /etc/atomic-update.conf.d, for the SteamOS update hang";
            After = [ "local-fs.target" ];
            ConditionPathIsDirectory = "/etc/atomic-update.conf.d";
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.escapeShellArgs [
              "${pkgs.coreutils}/bin/stat" "--format=%n" "/etc/atomic-update.conf.d"
            ];
          };
          Install.WantedBy = [ "multi-user.target" ];
        };
      };
    };
}
