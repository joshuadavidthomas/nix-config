# Every machine: the Mac, WSL, the lab boxes and VMs. lib/mksystem.nix gives it to vars.user
# everywhere, so every machine has the same tools, languages and agents. What only one
# platform can have goes in hosts/<name>/home.nix.
{ pkgs, ... }:
let
  pythonScript = name:
    pkgs.writeScriptBin name ("#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./files/${name});
in
{
  imports = [
    ./agents.nix
    ./atuin.nix
    ./cli.nix
    ./fish.nix
    ./git.nix
    ./neovim.nix
    ./nix.nix
    ./secrets.nix
    ./shell.nix
  ];

  home.stateVersion = "26.05"; # set once; don't bump it on upgrades

  # `man home-configuration.nix` is generated in a way current Nix warns about on every
  # build; the same reference is at home-manager-options.extranix.com.
  manual.manpages.enable = false;

  home.packages = (with pkgs; [
    bun
    cargo-binstall
    cf
    curl
    delta
    devenv
    dotenv-linter
    fastfetch
    fd
    ffmpeg
    flyctl
    gnupg
    go_1_27
    herdr
    himalaya
    jj-starship
    jjui
    jq
    just
    lisette
    llm
    lua5_5
    nodejs_24
    pnpm_12
    posting
    python314 # default python3; projects pin their own with uv/devenv
    rclone
    ripgrep
    rustic
    rustup
    tldr
    todoist-cli
    topgrade
    usage
    uv
    wakatime-cli
    wget
    zig
  ]) ++ [
    (pythonScript "git-rebase-feature-branch")
    (pythonScript "git-sclone")
    (pkgs.writeShellScriptBin "video2gif" ''
      PATH=${pkgs.ffmpeg}/bin:$PATH
      ${builtins.readFile ./files/video2gif}
    '')
  ];

  home.sessionVariables = {
    UV_SYSTEM_CERTS = "true";
  };

  home.shellAliases = {
    j = "just";
    lg = "lazygit";
  };
}
