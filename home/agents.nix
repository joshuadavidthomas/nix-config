# Coding agents and the hooks other tools add to them.
#
# Claude Code, Codex, opencode and pi release almost daily and T3 Code updates them in
# place, which only works when each comes from its own installer. Nix makes sure they're
# installed (activation below) and owns their config; the tools own their binaries.
#
# atuin's hooks (`atuin hook install <agent>`) are declared here; herdr and orca install
# their own helper scripts, and the hook entries below only call them when present.
{ lib, pkgs, ... }:
let
  json = pkgs.formats.json { };

  # npm globals go here instead of the read-only Nix node prefix; T3 Code detects
  # this prefix from the install path and updates with `npm install -g --prefix`.
  npmPrefix = "$HOME/.local";

  atuinHook = agent: matcher: [
    {
      inherit matcher;
      hooks = [
        {
          type = "command";
          command = "atuin hook ${agent}";
        }
      ];
    }
  ];

  herdrSessionStart = script: [
    {
      matcher = "*";
      hooks = [
        {
          type = "command";
          command = ''if [ -f "${script}" ]; then bash "${script}" session; fi'';
          timeout = 10;
        }
      ];
    }
  ];

  installerPath = lib.makeBinPath (with pkgs; [
    bash
    coreutils
    curl
    findutils
    gawk
    gnugrep
    gnused
    gnutar
    gzip
    nodejs_24
    unzip
    xz
  ]);
in
{
  home.packages = [ pkgs.amp-cli ];

  home.sessionVariables.NPM_CONFIG_PREFIX = npmPrefix;

  # Install each agent only if it's missing; afterwards it updates itself (or T3 Code does).
  # A failed download warns instead of failing the switch.
  home.activation.codingAgents = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
      # installers check PATH for their bin dir; without it Codex's tries to edit
      # ~/.zprofile, which Nix owns
      export PATH="$HOME/.local/bin:${installerPath}:/usr/bin:/bin"
      export NPM_CONFIG_PREFIX="${npmPrefix}"

      if [ ! -x "$HOME/.local/bin/claude" ]; then
        run ${pkgs.bash}/bin/bash -c 'curl -fsSL https://claude.ai/install.sh | bash' \
          || warnEcho "Claude Code install failed; rerun the switch to retry"
      fi

      if [ ! -x "$HOME/.local/bin/codex" ]; then
        CODEX_NON_INTERACTIVE=1 run ${pkgs.bash}/bin/bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh' \
          || warnEcho "Codex install failed; rerun the switch to retry"
      fi

      for pkg in @opencode/cli @earendil-works/pi-coding-agent; do
        if [ ! -d "$NPM_CONFIG_PREFIX/lib/node_modules/$pkg" ]; then
          run npm install -g --prefix "$NPM_CONFIG_PREFIX" --allow-scripts="$pkg" "$pkg" \
            || warnEcho "$pkg install failed; rerun the switch to retry"
        fi
      done
    )
  '';

  programs.claude-code = {
    enable = true;
    package = null; # native install in ~/.local/bin, self-updating
    settings = {
      agentPushNotifEnabled = true;
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
      theme = "auto";
      tui = "fullscreen";
      skipDangerousModePermissionPrompt = true;
      hooks = {
        PreToolUse = atuinHook "claude-code" "Bash";
        PostToolUse = atuinHook "claude-code" "Bash";
        PostToolUseFailure = atuinHook "claude-code" "Bash";
        SessionStart = herdrSessionStart "$HOME/.claude/hooks/herdr-agent-state.sh";
      };
    };
  };

  # config.toml stays Codex's: the app records trusted projects there.
  home.file.".codex/hooks.json".source = json.generate "codex-hooks.json" {
    hooks = {
      PreToolUse = atuinHook "codex" "^Bash$";
      PostToolUse = atuinHook "codex" "^Bash$";
      PostToolUseFailure = atuinHook "codex" "^Bash$";
      SessionStart = herdrSessionStart "$HOME/.codex/herdr-agent-state.sh";
    };
  };

  xdg.configFile."opencode/plugins/atuin.ts".source = ./files/opencode-atuin.ts;
  home.file.".pi/agent/extensions/atuin.ts".source = ./files/pi-atuin.ts;
}
