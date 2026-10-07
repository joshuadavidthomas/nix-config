{ pkgs, ... }: {
  home.stateVersion = "26.05"; # set once; don't bump it on upgrades

  home.packages = with pkgs; [
    devenv
    fd
    jq
    ripgrep
    uv
  ];

  programs.bash.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting
    '';
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
    gitCredentialHelper.enable = true; # git over HTTPS to github.com uses gh's token
  };

  programs.git = {
    enable = true;
    settings.user.name = "Josh Thomas";
  };

  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./dotfiles/starship.toml) // {
      scan_timeout = 100;   # ms; default 30
    };
  };
}
