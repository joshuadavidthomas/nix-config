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
  rex = inputs.rex.packages.${pkgs.system}.rex;
  # The tailnet side uses the deck's own tailscaled (SteamOS keeps its binary under
  # /opt/tailscale, on the home partition); the CLI that talks to it is that daemon's own
  # build, so the two cannot drift.
  tailscale = "/opt/tailscale/tailscale";
in {
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  # home-manager's own module for a machine where Nix does not manage the OS: it fills in
  # XDG paths and such, the same way it does on WSL.
  targets.genericLinux.enable = true;

  imports = [
    # Secrets, read with the service account's token. On the machines NixOS and macOS
    # configure, opnix runs as a system service; the Deck has neither, so its secrets come in
    # at the home-manager level instead (Stage 2, docs/new-deck.md). Its module skips the
    # fetch with a warning while the token is missing, so the first apply does not fail.
    inputs.opnix.homeManagerModules.default
    # Declarative /etc files and system services, for the keep-list, Rex's login server and
    # the SteamOS update-hang workaround (Stage 2, docs/new-deck.md).
    inputs.steamos-etc.homeManagerModules.default
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
    # same line as the Mac's (hosts/mac/home.nix) and a lab box's (nix-credentials in
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

  # Rex's flake input needs pkgs.superlogical.com's login (docs/rex.md). home/nix.nix owns the
  # base of this file on every machine and home-manager merges the texts.
  xdg.configFile."nix/nix.conf".text = ''
    netrc-file = ${config.xdg.configHome}/nix/netrc
  '';

  # Commits sign with the key opnix wrote (home/git.nix sets its default). Signing's own
  # config lives in 1Password for the Mac; the Deck names the file opnix wrote.
  programs.git.signing.key = config.programs.onepassword-secrets.secretPaths.gitSigningKey;

  programs.steamos-etc = {
      enable = true;
      # Hold the user session until /nix is mounted, so home-manager's links resolve at login
      waitForNix = true;

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

        # The Deck is a docked server: a suspend — SteamOS's idle one, a session's, or a lid
        # event — takes the tailnet with it. This holds a logind inhibitor open while it
        # runs, which blocks every suspend path that goes through logind. Valve's
        # auto-suspend and the sessions' own both do, so the screen can still go dark after
        # its own timeout, with CPU, Wi-Fi and services running behind the blank screen.
        # Both binaries are SteamOS's own and live on the always-present root, so this unit
        # does not reach into the store and survives every update by itself.
        # For a manual suspend, stop this unit first: `sudo systemctl stop deck-always-on`.
        "deck-always-on" = {
          Unit = {
            Description = "Inhibit suspend, so the deck stays reachable while docked";
            After = [ "multi-user.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = lib.escapeShellArgs [
              "/usr/bin/systemd-inhibit"
              "--what=sleep" "--who=deck" "--why=docked"
              "/usr/bin/sleep" "infinity"
            ];
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "multi-user.target" ];
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
