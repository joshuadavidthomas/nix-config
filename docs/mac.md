# Mac

The configuration supports Apple Silicon Macs only. All Macs use `darwinConfigurations.mac`.

## Set up a new Mac

1. Open Terminal.
2. Run the bootstrap:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
   ```

   The bootstrap installs Determinate Nix and applies the configuration from GitHub. It
   installs Homebrew, the apps and the tools, and clones the repo to `~/.nix-config`.

3. When the bootstrap waits for 1Password, sign in to the 1Password app.
4. Turn on Settings > Developer > Integrate with 1Password CLI. Approve the Touch ID prompt.

   The bootstrap continues. It gets the sops key from 1Password and applies the configuration
   again.

5. Turn on Settings > Developer > Use the SSH agent.
6. Open a new terminal.
7. Log in to GitHub:

   ```sh
   gh auth login
   ```

8. Test SSH. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

9. Apply again, so that Nix gets the GitHub token:

   ```sh
   rebuild
   ```

You can run the bootstrap again at any time. It skips the steps that are complete.

## Problems

| Problem | Cause | Action |
| --- | --- | --- |
| `You have not agreed to the Xcode license` stops a switch | Xcode was updated | Apply again. The configuration accepts the license before the Homebrew step. |
| `$HOME … is not owned by you` from `sudo nix …` | `sudo` keeps your `$HOME` | Use `sudo -H` |
| `darwin-rebuild: command not found` after the first switch | The shell does not have the nix-darwin paths | Run `sudo /run/current-system/sw/bin/darwin-rebuild …` once. Open a new terminal. |
| `Refusing to load formula … from untrusted tap` | Homebrew does not trust the tap | Add the tap to `taps` in `hosts/mac/default.nix` |
| An app is gone after a rollback | The older generation does not declare it | Apply again |
| The sops key is not fetched | 1Password is locked, or the CLI integration is off | Unlock 1Password. Turn on the CLI integration. Apply again. |
