# Shells and what all of them share: PATH, and direnv in shells that never draw a prompt.
# fish is the login shell; its interactive setup is in fish.nix.
#
# direnv's hook fires on the prompt, so shells that never draw one (agents' tool calls,
# editor tasks, `fish -c`) skip it. The direnv lines below load the directory's environment up
# front instead. direnv evaluates .envrc in bash, which reads BASH_ENV too: the marker keeps
# that bash, and anything the .envrc starts, from calling back into direnv. A shell that
# inherited a loaded environment keeps it: build tools run scripts from other directories
# (cargo runs the linker, a bash script, from each crate's source), where reloading would
# unload it. Claude Code loads it its own way (home/dev/agents.nix).
{ config, ... }:
let
  direnv = "${config.programs.direnv.package}/bin/direnv";

  # Kept last on PATH so Nix-managed tools win over installer copies left in these dirs.
  appendedPath = [
    "$HOME/.local/bin" # other apps' installers (hermes, sprite, swamp, openclaw)
    "$HOME/.cargo/bin" # `cargo install` output
  ];
in
{
  programs.bash = {
    enable = true; # minimal fallback for nix develop, recovery and scripts
    profileExtra = ''
      export PATH="$PATH:${builtins.concatStringsSep ":" appendedPath}"
    '';
  };

  programs.zsh = {
    enable = true; # login shell for GUI apps and agents that spawn $SHELL
    envExtra = ''
      path+=(${builtins.concatStringsSep " " (map (p: ''"${p}"'') appendedPath)})

      if [[ ! -o interactive && -z ''${DIRENV_DIR-} && -z ''${DIRENV_NONINTERACTIVE-} && -z ''${CLAUDECODE-} ]]; then
        eval "$(DIRENV_NONINTERACTIVE=1 DIRENV_LOG_FORMAT= ${direnv} export zsh 2>/dev/null)"
      fi
    '';
  };

  programs.fish.shellInit = ''
    fish_add_path --path --append ${builtins.concatStringsSep " " appendedPath}

    if not status is-interactive; and not set -q DIRENV_DIR; and not set -q DIRENV_NONINTERACTIVE
      DIRENV_NONINTERACTIVE=1 DIRENV_LOG_FORMAT= ${direnv} export fish 2>/dev/null | source
    end
  '';

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # A fixed path rather than a store path: apps keep the BASH_ENV they launched with, and this
  # way they still get the current hook after a switch.
  xdg.configFile."direnv/noninteractive.bash".text = ''
    if [[ -z ''${DIRENV_DIR-} && -z ''${DIRENV_NONINTERACTIVE-} ]]; then
      eval "$(DIRENV_NONINTERACTIVE=1 DIRENV_LOG_FORMAT= ${direnv} export bash 2>/dev/null)"
    fi
  '';
  home.sessionVariables.BASH_ENV = "${config.xdg.configHome}/direnv/noninteractive.bash";
}
