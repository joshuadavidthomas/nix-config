# Every machine: the Mac, WSL, the lab boxes and VMs. lib/mksystem.nix gives it to vars.user
# everywhere, so ssh into any box and the tools are there. home/dev adds what's only needed
# where you write code.
{ pkgs, ... }:
let
  pythonScript = name:
    pkgs.writeScriptBin name ("#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./files/${name});
in
{
  imports = [
    ./atuin.nix
    ./cli.nix
    ./fish.nix
    ./git.nix
    ./neovim.nix
    ./shell.nix
  ];

  home.stateVersion = "26.05"; # set once; don't bump it on upgrades

  # `man home-configuration.nix` is generated in a way current Nix warns about on every
  # build; the same reference is at home-manager-options.extranix.com.
  manual.manpages.enable = false;

  home.packages = (with pkgs; [
    cf
    curl
    delta
    dotenv-linter
    fastfetch
    fd
    ffmpeg
    flyctl
    gnupg
    herdr
    himalaya
    jj-starship
    jjui
    jq
    just
    llm
    posting
    rclone
    ripgrep
    rustic
    tldr
    todoist-cli
    topgrade
    usage
    uv
    wakatime-cli
    wget
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
