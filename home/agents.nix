# Coding agents and the hooks other tools add to them.
#
# Amp, Claude Code, Codex, opencode and pi release almost daily and T3 Code updates them in
# place, which only works when each comes from its own installer. Nix makes sure they're
# installed (activation below) and owns their config; the tools own their binaries.
# Cloudflare's `cf` CLI is installed the same way: it's in beta and releases too often to pin.
#
# atuin's hooks (`atuin hook install <agent>`) are declared here; herdr and orca install
# their own helper scripts, and the hook entries below only call them when present.
{ config, lib, pkgs, ... }:
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

  direnvLoad = ''eval "$(DIRENV_NONINTERACTIVE=1 DIRENV_LOG_FORMAT= ${config.programs.direnv.package}/bin/direnv export bash 2>/dev/null)"'';

  claudeSettings = json.generate "claude-settings.json" {
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
      SessionStart = herdrSessionStart "$HOME/.claude/hooks/herdr-agent-state.sh" ++ [
        {
          hooks = [
            {
              # Claude restores its PATH snapshot after .zshenv; load direnv afterwards.
              type = "command";
              command = ''grep -qxF ${lib.escapeShellArg direnvLoad} "$CLAUDE_ENV_FILE" 2>/dev/null || echo ${lib.escapeShellArg direnvLoad} >> "$CLAUDE_ENV_FILE"'';
            }
          ];
        }
      ];
    };
  };

  # Only hooks.json: config.toml stays Codex's, the app records trusted projects there.
  codexHooks = json.generate "codex-hooks.json" {
    hooks = {
      PreToolUse = atuinHook "codex" "^Bash$";
      PostToolUse = atuinHook "codex" "^Bash$";
      PostToolUseFailure = atuinHook "codex" "^Bash$";
      SessionStart = herdrSessionStart "$HOME/.codex/herdr-agent-state.sh";
    };
  };

  # Agents and tools such as Rex write these files too, so Nix merges its settings into them
  # instead of linking a read-only copy. Objects merge recursively and Nix wins for the keys it
  # declares. Hook events are lists that others add to, so Nix replaces only the entries it
  # wrote on the previous switch, recorded in .nix-managed-hooks.json next to the file.
  # Runs before Home Manager removes an old symlink to the file, which becomes a regular file.
  mergeAgentJsonProgram = ''
    def drop($xs): map(. as $e | select(any($xs[]; . == $e) | not));
    ($current[0] // {}) as $c | $managed[0] as $n | ($previous[0] // {}) as $p
    | if ($c | type) != "object" then error("\($file) must be a JSON object") else . end
    | ($c.hooks // {}) as $h | ($n.hooks // {}) as $nh
    | (reduce ((($h | keys) + ($nh | keys)) | unique)[] as $k ({};
        .[$k] = ((($h[$k] // []) | drop($p[$k] // []) | drop($nh[$k] // [])) + ($nh[$k] // [])))
      | with_entries(select(.value != []))) as $hooks
    | ($c * ($n | del(.hooks))) + { hooks: $hooks }
  '';

  mergeAgentJson = name: target: managed: lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    merge${name}() (
      set -eu
      target="${target}"
      state="$(dirname "$target")/.nix-managed-hooks.json"
      mkdir -p "$(dirname "$target")"
      if [ -L "$target" ] && [ ! -e "$target" ]; then
        echo "$target is a broken symlink" >&2
        exit 1
      fi
      current=/dev/null
      if [ -e "$target" ]; then current="$target"; fi
      previous=/dev/null
      if [ -e "$state" ]; then previous="$state"; fi
      temp=$(mktemp "$target.XXXXXXXX")
      trap 'rm -f "$temp" "$temp.hooks"' EXIT
      ${pkgs.jq}/bin/jq -n -e --arg file "$target" \
        --slurpfile current "$current" --slurpfile managed ${managed} --slurpfile previous "$previous" \
        ${lib.escapeShellArg mergeAgentJsonProgram} > "$temp"
      ${pkgs.jq}/bin/jq -e '.hooks // {}' ${managed} > "$temp.hooks"
      mv -f "$temp" "$target"
      mv -f "$temp.hooks" "$state"
    )
    run merge${name}
  '';

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

      # binary in ~/.amp/bin, symlinked into ~/.local/bin
      if [ ! -x "$HOME/.local/bin/amp" ]; then
        run ${pkgs.bash}/bin/bash -c 'curl -fsSL https://ampcode.com/install.sh | bash' \
          || warnEcho "Amp install failed; rerun the switch to retry"
      fi

      if [ ! -x "$HOME/.local/bin/codex" ]; then
        CODEX_NON_INTERACTIVE=1 run ${pkgs.bash}/bin/bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh' \
          || warnEcho "Codex install failed; rerun the switch to retry"
      fi

      for pkg in @opencode/cli @earendil-works/pi-coding-agent cf; do
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
  };

  home.activation.claudeSettings = mergeAgentJson "ClaudeSettings" "$HOME/.claude/settings.json" claudeSettings;
  home.activation.codexHooks = mergeAgentJson "CodexHooks" "$HOME/.codex/hooks.json" codexHooks;

  xdg.configFile."opencode/plugins/atuin.ts".source = ./files/opencode-atuin.ts;
  home.file.".pi/agent/extensions/atuin.ts".source = ./files/pi-atuin.ts;
}
