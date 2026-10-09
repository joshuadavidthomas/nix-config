# Set up a new Mac

All Macs use the same configuration, `darwinConfigurations.mac`. A new Mac needs no change to
the repo. The configuration supports Apple Silicon only.

## What you need

- A Mac with Apple Silicon
- Your 1Password account

## Procedure

1. Open Terminal.
2. Run the bootstrap:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
   ```

   The bootstrap installs Nix and applies the configuration. Then it waits for 1Password.

3. Sign in to the 1Password app.
4. In 1Password, turn on Settings > Developer > Integrate with 1Password CLI.
5. Approve the Touch ID prompt.

   The bootstrap applies the configuration again. During this apply, the `sopsAgeKey` step
   gets the age key from 1Password.

6. In 1Password, turn on Settings > Developer > Use the SSH agent.
7. Open a new terminal.
8. Log in to GitHub:

   ```sh
   gh auth login
   ```

9. Test SSH. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

10. Apply again, so that Nix gets the GitHub token:

    ```sh
    rebuild
    ```

The bootstrap is safe to run again. It skips the steps that are complete. `bootstrap.sh`
describes each step at the top of the file.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `You have not agreed to the Xcode license` | Xcode was installed or updated | Apply again. The configuration accepts the license before Homebrew runs. |
| `$HOME ('/Users/josh') is not owned by you` | `sudo` without `-H` | Use `sudo -H` |
| `darwin-rebuild: command not found` | The terminal started before the first apply | Open a new terminal |
| `Refusing to load formula … from untrusted tap` | The tap is not in `taps` | Add the tap to `taps` in `hosts/mac/default.nix` |
| The bootstrap waits for 1Password and does not continue | The CLI integration is off, or 1Password is locked | Do steps 3 to 5 |
