# The config lives in its own repo (github.com/joshuadavidthomas/nvim); Nix provides
# the editor and providers and makes sure the checkout exists.
{ lib, pkgs, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true; # node provider (was npm:neovim under mise)
    withPython3 = false; # python provider is the config repo's uv-managed .venv
    withRuby = false;
    sideloadInitLua = true; # never write ~/.config/nvim/init.lua
  };

  home.activation.nvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/nvim" ]; then
      run ${lib.getExe pkgs.git} clone https://github.com/joshuadavidthomas/nvim "$HOME/.config/nvim"
    fi
  '';
}
