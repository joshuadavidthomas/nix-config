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
    atuin
    bun
    cargo-binstall
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
    neovim-node-client
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
    xcodegen
    yazi
    zoxide
    ;

  # yonder, from its flake input, named as the release tag flake.nix pins. A Nix build of a tag
  # learns its commit but not its name, so the name is read from flake.lock, where `nix flake
  # lock` wrote it as the input's original ref; null (a pin by commit) or a branch's name builds
  # a development build (yonder's wiki/designs/releases.md). The lab boxes' yonderd and the
  # Mac's CLI both use this one.
  # Releases before v0.1.0-rc9 take no name (they carry a VERSION file) and are used as they are.
  yonder =
    let pinned = inputs.yonder.packages.${prev.stdenv.hostPlatform.system}.yonder; in
    if prev.lib.functionArgs pinned.override ? release then
      pinned.override {
        release = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.yonder.original.ref or null;
      }
    else pinned;
}
