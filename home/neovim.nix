# The config lives in its own repo (github.com/joshuadavidthomas/nvim); Nix provides
# the editor and providers and makes sure the checkout exists.
{ lib, pkgs, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true; # node provider (was npm:neovim under mise)
    # leaves the python provider enabled; the config's globals.lua points it at the
    # repo's uv-managed .venv (pynvim plus the spotify rplugin workspace)
    withPython3 = true;
    withRuby = false;
    sideloadInitLua = true; # never write ~/.config/nvim/init.lua
  };

  home.activation.nvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/nvim" ]; then
      run ${lib.getExe pkgs.git} clone https://github.com/joshuadavidthomas/nvim "$HOME/.config/nvim"
    fi
    if [ ! -e "$HOME/.config/nvim/.venv" ]; then
      run ${lib.getExe pkgs.uv} sync --project "$HOME/.config/nvim" --locked \
        || warnEcho "nvim: python provider venv failed; run 'uv sync' in ~/.config/nvim"
    fi
  '';
}
