# Work-only settings (work git email, proxies) live here, never in home/.
{ pkgs, ... }: {
  home.packages = [ pkgs.wsl-open ];
  programs.neovim.extraPackages = [ pkgs.gcc ]; # cc for tree-sitter parsers; the Mac uses Xcode's
  home.sessionVariables.BROWSER = "wsl-open";
  programs.gh.settings.browser = "wsl-open";
  programs.git = {
    settings = {
      user.email = "jthomas@westervelt.com";
      core.sshCommand = "ssh.exe";
    };
    signing.signer = "/mnt/c/Users/jthomas/AppData/Local/Microsoft/WindowsApps/op-ssh-sign.exe";
  };
  programs.jujutsu.settings.user.email = "jthomas@westervelt.com";
  home.shellAliases = {
    ssh = "ssh.exe";
    ssh-add = "ssh-add.exe";
  };
}
