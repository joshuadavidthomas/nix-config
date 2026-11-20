# Set up a new Mac

Each Mac has its own configuration in `flake.nix` (`darwinConfigurations`), such as
`mac-mini`. Every Mac gets `modules/darwin`. `hosts/<name>/` adds what only that Mac has.

## Add the Mac to the repo

Do this on a Mac that already has the configuration. Skip it if the Mac is already in
`flake.nix`, for example when you set up the same Mac again.

1. Find the account name that the new Mac uses. On a new Mac, it is `josh`. On a Mac that is
   already set up, see [Check the account](#check-the-account).
2. Create `hosts/<name>/default.nix`. For a Mac with nothing of its own:

   ```nix
   # The <description> Mac.
   { ... }: { }
   ```

3. Add the Mac to `darwinConfigurations` in `flake.nix`:

   ```nix
   <name> = mkSystem "<name>" { system = "aarch64-darwin"; };
   ```

   If the account name is not `josh`, add `user = "<account name>";`.
4. Run `git add hosts/<name>` and `nix flake check`.
5. Commit and push. The bootstrap reads `flake.nix` from GitHub.

## What you need

- A Mac with Apple Silicon
- Your Apple Account
- Your 1Password account

## Set up macOS

Setup Assistant starts when you turn on the new Mac.

1. Select your language, region and Wi-Fi network.
2. On the Migration Assistant screen, select **Not Now**. The bootstrap installs the apps and
   settings. Copy the files that you need from the old Mac after setup.
3. Sign in with your Apple Account.
4. Create the user account:
   - Full name: `Josh Thomas`
   - Account name: `josh`

   Make it the first account on the Mac (uid 501). Do not create a different account first.
5. Turn on FileVault when Setup Assistant asks.
6. If the Mac has Touch ID, add your fingerprint when Setup Assistant asks. To add it later,
   open System Settings > Touch ID & Password. 1Password uses Touch ID to approve the CLI and
   the SSH agent.
7. Complete the other Setup Assistant screens.
8. Open System Settings > General > Software Update and install all updates. Restart if
   macOS asks.

## Use a Mac that is already set up

Do this section instead of [Set up macOS](#set-up-macos) when Setup Assistant has already
run, for example on a Mac that an employer set up and installed apps on.

### Check the account

1. Log in to the account that you will use.
2. Make sure that the account is an administrator. The bootstrap uses `sudo` to install Nix
   and to apply the configuration. If the account is a standard user, ask IT for
   administrator access.
3. Show the account name, uid and home folder:

   ```sh
   id -un; id -u; echo "$HOME"
   ```

| Result | Action |
| --- | --- |
| An account name other than `josh` | Give the account name as `user` when you [add the Mac to the repo](#add-the-mac-to-the-repo). |
| A home folder other than `/Users/<account name>` | The configuration does not support this. |
| A uid other than `501` | You can continue. The switch prints `existing user '<account>' has unexpected uid` and does not set fish as the login shell. Everything else applies. |

Do not rename an account that the employer manages. If `app-sso platform -s` shows
`"registrationCompleted" : true`, the company login (Platform SSO) is tied to the account,
and a rename can stop it. Give the account name as `user` in `flake.nix` instead.

### Check Homebrew

The configuration removes all Homebrew formulae and casks that `modules/darwin/default.nix` does
not declare. Apps that IT installed with MDM or a `.pkg` are not in Homebrew, and the
configuration does not touch them.

1. If Homebrew is installed, list what it installed:

   ```sh
   brew list --formula; brew list --cask
   ```

2. Compare the list with `brews` and `casks` in `modules/darwin/default.nix`. The first switch
   removes each item that is not declared there. If the employer needs one of them, ask IT
   before you continue.
3. Apps in `/Applications` that a cask in `casks` also installs, for example 1Password,
   need no action. The switch adopts them: Homebrew records the app as its own and does not
   change it. A cask that installs with a `.pkg`, such as `microsoft-teams`, installs over
   the app. After this, `brew upgrade` updates these apps, and if you remove the cask from
   `casks`, the next switch uninstalls the app.

### Then

1. Do steps 6 and 8 of [Set up macOS](#set-up-macos): Touch ID and software updates.
2. Go to [Install the configuration](#install-the-configuration). If the 1Password app is
   already signed in to a company account, also sign in to your own account. The bootstrap
   reads the token from the Private vault of your account.

## Install the configuration

1. Open Terminal.
2. Run the bootstrap with the Mac's name in `flake.nix`, for example `mac-mini`:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh -s -- mac-mini
   ```

3. When the bootstrap asks you to log in to GitHub, press Enter and approve the code in the
   browser. Nix uses this token to fetch private inputs, such as yonder.
4. When the bootstrap asks for 1Password, sign in to the 1Password app.
5. In 1Password, turn on Settings > Developer > Integrate with 1Password CLI.
6. Approve the prompt with Touch ID, or with your password on a Mac without Touch ID. The
   bootstrap copies the opnix token from 1Password.
7. In 1Password, turn on Settings > Developer > Use the SSH agent.
8. Open a new terminal.
9. Test SSH. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

You can run the bootstrap again at any time, with the same name.

The Mac includes Mole's `mo` CLI for cleanup and disk analysis. Preview cleanup with
`mo clean --dry-run` before removing anything. Homebrew updates Mole along with its other formulae.
The Mac also installs Hex from the `anomalyco/tap` Homebrew tap.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `You have not agreed to the Xcode license` | Xcode was installed or updated | Apply again |
| `missing Metal Toolchain` when a GPUI app builds | Xcode was installed or updated | Apply again; it downloads the toolchain |
| `$HOME ('/Users/josh') is not owned by you` | `sudo` without `-H` | Use `sudo -H` |
| `No "base" settings found` from xcodegen | The user profile does not link `share/xcodegen` | Add it to `environment.pathsToLink` in `modules/darwin/default.nix`. Apply again. |
| `reddit-proxy.joshthomas.dev` returns 530 | The `micro-hunter-tunnel` daemon on the Mac mini is down | `sudo launchctl print system/org.nixos.micro-hunter-tunnel`, and `~/Library/Application Support/micro-hunter/tunnel.log` |
| `The bundle version of … is … but is … for /Applications/…` | An app that was installed outside Homebrew has a different version from the cask, and the cask does not update itself, so Homebrew does not adopt it | Delete the app from `/Applications`, then apply again |
| `flake.nix on GitHub has no Mac configuration …` | The Mac is not in `flake.nix` on GitHub | [Add the Mac to the repo](#add-the-mac-to-the-repo), push, and run the bootstrap again |
| `… is for the account …, but you are logged in as …` | The `user` of the configuration is not this account | Log in to the right account, or correct `user` in `flake.nix` |
| `existing user '…' has unexpected uid` | The account is not uid 501 | No action. The login shell stays as it was. See [Check the account](#check-the-account). |
| `config contains the wrong home directory for …` | The home folder is not `/Users/<account name>` | The configuration does not support this |
| `darwin-rebuild: command not found` | The terminal started before the first apply | Open a new terminal |
| `Refusing to load formula … from untrusted tap` | The tap is not in `taps` | Add the tap to `taps` in `modules/darwin/default.nix` |
| The bootstrap waits for 1Password and does not continue | The CLI integration is off, or 1Password is locked | Do steps 4 to 6 of [Install the configuration](#install-the-configuration) |
| `HTTP error 404` for a `github.com/…/archive/…` URL | The GitHub login is missing or expired | Run `gh auth login`, then the bootstrap again |
| `opnix fetched nothing in 2 minutes` | The token is wrong, or the Mac is offline | Read `/var/log/opnix-secrets.log`. To copy the token again, run `sudo rm /etc/opnix-token` and the bootstrap. |
