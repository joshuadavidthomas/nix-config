# How to set up a new Mac

The configuration supports Apple Silicon Macs only.

## Run the bootstrap

1. Open Terminal.
2. Run the bootstrap:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
   ```

The bootstrap installs Determinate Nix and applies the configuration from GitHub. This
installs Homebrew, the apps (1Password included) and the tools. It also clones the repo to
`~/.nix-config`.

If the switch stops at the Xcode license, run the bootstrap again. You can run it again at
any time. It skips the steps that are complete.

## Connect 1Password

The bootstrap stops and waits for 1Password. Do these steps:

1. Sign in to the 1Password app.
2. Turn on Settings > Developer > Integrate with 1Password CLI.
3. Turn on Settings > Developer > Use the SSH agent.
4. Approve the Touch ID prompt.

The bootstrap then applies the configuration again. This time it gets the sops key from
1Password and installs the secrets.

## Finish

1. Open a new terminal.
2. Log in to GitHub:

   ```sh
   gh auth login
   ```

3. Test SSH to GitHub. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

4. Apply the configuration again, so that Nix gets the GitHub token:

   ```sh
   rebuild
   ```

To make changes later, see [Apply, update and roll back](apply-update-roll-back.md).
