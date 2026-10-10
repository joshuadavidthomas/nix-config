# Set up a new Mac

A new Mac needs no change to the repo.

## What you need

- A Mac with Apple Silicon
- The service account token: the item "Service Account Auth Token: dotfiles" in your
  Private vault in 1Password. Open it on another device.

## Procedure

1. Open Terminal.
2. Run the bootstrap:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
   ```

3. When the bootstrap asks for the token, paste it and press Enter. The token does not show.
4. Sign in to the 1Password app.
5. In 1Password, turn on Settings > Developer > Use the SSH agent.
6. Open a new terminal.
7. Log in to GitHub:

   ```sh
   gh auth login
   ```

8. Test SSH. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

9. Apply again. This gives Nix the GitHub token.

   ```sh
   rebuild
   ```

You can run the bootstrap again at any time.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `You have not agreed to the Xcode license` | Xcode was installed or updated | Apply again |
| `$HOME ('/Users/josh') is not owned by you` | `sudo` without `-H` | Use `sudo -H` |
| `darwin-rebuild: command not found` | The terminal started before the first apply | Open a new terminal |
| `Refusing to load formula … from untrusted tap` | The tap is not in `taps` | Add the tap to `taps` in `hosts/mac/default.nix` |
| `opnix fetched nothing in 2 minutes` | The token is wrong, or the Mac is offline | Read `/var/log/opnix-secrets.log`. To enter the token again, run `sudo rm /etc/opnix-token` and the bootstrap. |
