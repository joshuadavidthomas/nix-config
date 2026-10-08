# The one place package versions are decided. Every machine applies this overlay, and it's
# exported as overlays.default for project devenvs, so `pkgs.<name>` means the same thing
# everywhere and modules never pick versions themselves.
#
# Only standalone CLI tools come from nixpkgs-unstable, where they track upstream closely.
# Runtimes and libraries (python, node, go, curl, ffmpeg, ...) stay on the release branch:
# replacing those would rebuild everything that depends on them.
inputs: final: prev:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
    overlays = [ (import ./pkgs inputs) ]; # packages nixpkgs lacks or trails on
  };
in
{
  inherit (unstable)
    _1password-cli
    amp-cli
    atuin
    bun
    cargo-binstall
    cf
    delta
    devenv
    eza
    fastfetch
    fd
    flyctl
    fzf
    gh
    glow
    herdr
    himalaya
    jj-starship
    jjui
    jujutsu
    just
    lazygit
    lisette
    llm
    neovim-unwrapped
    posting
    ripgrep
    rustic
    starship
    tmux
    todoist-cli
    topgrade
    usage
    uv
    wakatime-cli
    yazi
    zoxide
    ;
}
