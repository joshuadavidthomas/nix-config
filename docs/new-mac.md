# Set up a new Mac

One procedure for every Mac: a new personal Mac, a Mac that you set up again, and a Mac that
an employer set up. You need only the new Mac. The bootstrap adds a new Mac to the repo, and
pushes the change at the end.

## What you need

- A Mac with Apple Silicon
- Your Apple Account
- Your 1Password account
- A name for the Mac, of lowercase letters, digits and `-`, such as `mac-mini`. For a Mac
  that is already in the repo, use its name in `hosts/`.

## How the repo knows a Mac

Each Mac is a directory `hosts/<name>/`:

- `mac.json`: the account name, and `preinstalledCasks`, the apps that were on the Mac
  before Homebrew. The bootstrap writes this file. `flake.nix` makes a configuration for
  each `hosts/<name>/` that has one.
- `default.nix`, if the Mac has one: what only that Mac has, such as micro-hunter's services
  on the Mac mini.

Every Mac gets `modules/darwin`: the tools, the apps, the secrets and `rebuild`.

## 1. Set up macOS

Do this on a new Mac. On a Mac that Setup Assistant has already set up, for example one from
an employer, go to [Use a Mac that is already set up](#use-a-mac-that-is-already-set-up).

1. Select your language, region and Wi-Fi network.
2. On the Migration Assistant screen, select **Not Now**. The bootstrap installs the apps and
   settings. Copy the files that you need from the old Mac after setup.
3. Sign in with your Apple Account.
4. Create the user account. Make it the first account on the Mac (uid 501).
   - Full name: `Josh Thomas`
   - Account name: `josh`
5. Turn on FileVault when Setup Assistant asks.
6. If the Mac has Touch ID, add your fingerprint when Setup Assistant asks. To add it later,
   open System Settings > Touch ID & Password. 1Password uses Touch ID to approve the CLI and
   the SSH agent.
7. Complete the other Setup Assistant screens.
8. Open System Settings > General > Software Update and install all updates. Restart if
   macOS asks.

### Use a Mac that is already set up

1. Log in to the account that you will use. The bootstrap uses its name. Do not rename an
   account that the employer manages: if `app-sso platform -s` shows
   `"registrationCompleted" : true`, the company login (Platform SSO) is tied to the account
   name, and a rename can stop it.
2. Make sure that the account is an administrator. The bootstrap uses `sudo`. If the account
   is a standard user, ask IT for administrator access.
3. If the Mac has Touch ID and no fingerprint, add one in System Settings > Touch ID &
   Password.
4. Sign in with your Apple Account, if it is not signed in. The configuration does not need
   it, so select one of these:
   - App Store only: open the App Store, then select Store > Sign In. No iCloud data comes
     to the Mac.
   - iCloud: open System Settings and select **Sign in** at the top of the sidebar. `memo`
     and `remindctl` then work with your Apple Notes and Reminders.

   On a Mac that an employer manages, IT holds the FileVault recovery key and can erase the
   Mac. Data that iCloud syncs to the Mac is on a computer that IT controls. IT can also
   block iCloud with a profile: `sudo profiles show | grep -i -E 'icloud|allowCloud'` shows
   no lines when there is no such profile.
5. Set your own login password, if IT gave you one. Find out first if the company login
   owns it:

   ```sh
   app-sso platform -s | grep -i logintype
   ```

   - `"loginType" : "POLoginTypePassword …"`: Platform SSO syncs the login password with
     your company password. Change the company password in the company's account portal. At
     the next login, macOS asks for the new password and updates the Mac. Do not change the
     password in System Settings: the next sync replaces it.
   - `"loginType" : "POLoginTypeUserSecureEnclaveKey …"`, or no output: the login password
     is the Mac's own. Platform SSO uses a key in the Secure Enclave, not the password. Open
     System Settings > Users & Groups, select **i** next to your account, and select
     **Change Password**. macOS also changes the login keychain and FileVault password.

   The bootstrap uses this password for `sudo`.
6. Install all software updates.

Apps that IT installed stay IT's. The bootstrap finds them and records them in
`preinstalledCasks`, so Homebrew does not install, adopt, update or remove them on this Mac.

## 2. Run the bootstrap

1. Open Terminal.
2. Run the bootstrap with the Mac's name:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh -s -- <name>
   ```

3. Enter your password when the bootstrap asks. It installs Nix and Homebrew.
4. When the bootstrap asks you to log in to GitHub, press Enter and approve the code in the
   browser.
5. Wait. The bootstrap clones the repo to `~/.nix-config`. For a new name, it adds the Mac to
   the repo, with your account. Then it records the apps that are already on the Mac and does
   the first switch.
6. When the bootstrap asks for 1Password, sign in to the 1Password app. On a Mac where it is
   already signed in to a company account, also sign in to your own account.
7. In 1Password, turn on Settings > Developer > Integrate with 1Password CLI.
8. Approve the prompt with Touch ID, or with your password on a Mac without Touch ID. The
   bootstrap copies the opnix token from 1Password and switches again.
9. When the bootstrap asks, turn on Settings > Developer > Use the SSH agent in 1Password.
   If the bootstrap changed `hosts/<name>`, it commits and pushes the change.
10. Open a new terminal. From now on, `rebuild` applies changes.

You can run the bootstrap again at any time, with the same name. Each step skips what is
already done.

On a Mac with Microsoft Defender, the first switch can be slow: Defender scans each file
that Nix writes to `/nix/store`.

## Change what the bootstrap recorded

`hosts/<name>/mac.json` is a file in the repo. Edit it, then `rebuild`.

- To let Homebrew manage an app from `preinstalledCasks`, remove the cask from the list,
  delete the app from `/Applications`, and `rebuild`. Homebrew installs its own copy.
- To keep an app that IT installed later away from Homebrew, add its cask to the list.

The Mac includes Mole's `mo` CLI for cleanup and disk analysis. Preview cleanup with
`mo clean --dry-run` before removing anything. Homebrew updates Mole along with its other formulae.
The Mac also installs Hex from the `anomalyco/tap` Homebrew tap.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `hosts/… is for the account …, but you are logged in as …` | The name is a Mac with another account | Log in to that account, or give this Mac another name |
| `hosts/… is not a Mac` | The name is a machine that is not a Mac, such as `lab-1` | Give this Mac another name |
| `The push failed` | `main` changed in a way that does not rebase, or the network is down | Push from `~/.nix-config` |
| `preinstalledCasks: … is not a cask in modules/darwin/default.nix` | A name in `mac.json` is not in `casks` | Correct the name. Use the name in `casks`, with its tap. |
| `existing user '…' has unexpected uid` | The account is not uid 501 | No action. The login shell stays as it was; everything else applies. |
| `config contains the wrong home directory for …` | The home folder is not `/Users/<account name>` | The configuration does not support this |
| `You have not agreed to the Xcode license` | Xcode was installed or updated | Apply again |
| `missing Metal Toolchain` when a GPUI app builds | Xcode was installed or updated | Apply again; it downloads the toolchain |
| `$HOME ('/Users/…') is not owned by you` | `sudo` without `-H` | Use `sudo -H` |
| `No "base" settings found` from xcodegen | The user profile does not link `share/xcodegen` | Add it to `environment.pathsToLink` in `modules/darwin/default.nix`. Apply again. |
| `reddit-proxy.joshthomas.dev` returns 530 | The `micro-hunter-tunnel` daemon on the Mac mini is down | `sudo launchctl print system/org.nixos.micro-hunter-tunnel`, and `~/Library/Application Support/micro-hunter/tunnel.log` |
| `darwin-rebuild: command not found` | The terminal started before the first apply | Open a new terminal |
| `Refusing to load formula … from untrusted tap` | The tap is not in `taps` | Add the tap to `taps` in `modules/darwin/default.nix` |
| The bootstrap waits for 1Password and does not continue | The CLI integration is off, or 1Password is locked | Do steps 6 to 8 of [Run the bootstrap](#2-run-the-bootstrap) |
| `HTTP error 404` for a `github.com/…/archive/…` URL | The GitHub login is missing or expired | Run `gh auth login`, then the bootstrap again |
| `opnix fetched nothing in 2 minutes` | The token is wrong, or the Mac is offline | Read `/var/log/opnix-secrets.log`. To copy the token again, run `sudo rm /etc/opnix-token` and the bootstrap. |
