# Work-only settings (work git email, proxies) live here, never in home/.
{ lib, pkgs, vars, ... }: {
  home.packages = [
    pkgs.wsl-open
    # Apply ~/.nix-config; extra arguments pass through (e.g. `rebuild --rollback`). The first
    # time, it copies the opnix token from 1Password for Windows (modules/secrets.nix).
    (pkgs.writeShellScriptBin "rebuild" ''
      if ! sudo test -s /etc/opnix-token; then
        op.exe ${lib.escapeShellArgs vars.opnixTokenArgs} | sudo sh -c 'umask 077; cat > /etc/opnix-token'
        sudo systemctl restart opnix-secrets 2>/dev/null || true
      fi
      exec sudo nixos-rebuild switch --flake "$HOME/.nix-config#work-wsl" "$@"
    '')
  ];
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
