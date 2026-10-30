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

3. When the bootstrap asks you to log in to GitHub, press Enter and approve the code in the
   browser. Nix uses this token to fetch private inputs, such as yonder.
4. When the bootstrap asks for 1Password, sign in to the 1Password app.
5. In 1Password, turn on Settings > Developer > Integrate with 1Password CLI.
6. Approve the Touch ID prompt. The bootstrap copies the opnix token from 1Password.
7. In 1Password, turn on Settings > Developer > Use the SSH agent.
8. Open a new terminal.
9. Test SSH. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

You can run the bootstrap again at any time.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `You have not agreed to the Xcode license` | Xcode was installed or updated | Apply again |
| `missing Metal Toolchain` when a GPUI app builds | Xcode was installed or updated | Apply again; it downloads the toolchain |
| `$HOME ('/Users/josh') is not owned by you` | `sudo` without `-H` | Use `sudo -H` |
| `darwin-rebuild: command not found` | The terminal started before the first apply | Open a new terminal |
| `Refusing to load formula … from untrusted tap` | The tap is not in `taps` | Add the tap to `taps` in `hosts/mac/default.nix` |
| The bootstrap waits for 1Password and does not continue | The CLI integration is off, or 1Password is locked | Do steps 4 to 6 |
| `HTTP error 404` for a `github.com/…/archive/…` URL | The GitHub login is missing or expired | Run `gh auth login`, then the bootstrap again |
| `opnix fetched nothing in 2 minutes` | The token is wrong, or the Mac is offline | Read `/var/log/opnix-secrets.log`. To copy the token again, run `sudo rm /etc/opnix-token` and the bootstrap. |
