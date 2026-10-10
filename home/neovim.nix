# The config lives in its own repo (github.com/joshuadavidthomas/nvim); Nix provides
# the editor and providers and makes sure the checkout exists.
{ lib, pkgs, ... }:
let
  # The Mac uses Xcode's compilers. Linux gets gcc, for tree-sitter parsers and for Python
  # packages that have no wheel for the venv's Python (pynvim's greenlet).
  compilers = lib.optionals pkgs.stdenv.isLinux [ pkgs.gcc ];
in
{
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
    extraPackages = compilers;
  };

  home.activation.nvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/nvim" ]; then
      run ${lib.getExe pkgs.git} clone https://github.com/joshuadavidthomas/nvim "$HOME/.config/nvim"
    fi
    # every switch: a no-op when the venv is current, and it repairs one that a failed run left
    run env PATH="${lib.concatMapStrings (p: "${p}/bin:") compilers}$PATH" ${lib.getExe pkgs.uv} sync --project "$HOME/.config/nvim" --locked \
      || warnEcho "nvim: python provider venv failed; run 'uv sync' in ~/.config/nvim"
  '';
}
