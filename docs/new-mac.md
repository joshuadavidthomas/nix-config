# Set up a new Mac

A new Mac needs no change to the repo.

## What you need

- A Mac with Apple Silicon
- Your 1Password account

## Procedure

1. Open Terminal.
2. Run the bootstrap:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
   ```

3. When the bootstrap asks for 1Password, sign in to the 1Password app.
4. In 1Password, turn on Settings > Developer > Integrate with 1Password CLI.
5. Approve the Touch ID prompt.
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

10. Apply again. This gives Nix the GitHub token.

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
| The bootstrap waits for 1Password and does not continue | The CLI integration is off, or 1Password is locked | Do steps 3 to 5 |
