# First steps with Nix

Here, we use Nix to run a program, then find it in the store. Next, we read a value
from the Mac configuration. Last, we add a package and roll the change back. At the end, the
Mac is the same as at the start.

You need a Mac set up from this repo, and your Mac password.

## Run a program without installing it

1. Run cowsay:

   ```sh
   nix run nixpkgs#cowsay -- hello
   ```

   A cow says "hello".

2. Look for cowsay on your PATH:

   ```sh
   command -v cowsay
   ```

   The command prints nothing. Nix ran cowsay, but did not install it.

## Find the program in the store

1. Start a shell that has cowsay:

   ```sh
   nix shell nixpkgs#cowsay
   ```

2. Find cowsay again:

   ```sh
   command -v cowsay
   ```

   The command prints a path that starts with `/nix/store/`. Each package has its own
   directory in the store.

3. Show the packages that cowsay needs:

   ```sh
   nix path-info -rsSh nixpkgs#cowsay
   ```

4. Leave the shell:

   ```sh
   exit
   ```

## Read a value from the configuration

1. Open the repo in the Nix REPL:

   ```sh
   cd ~/.nix-config
   nix repl
   ```

2. Load the repo:

   ```text
   :lf .
   ```

3. Ask for your git email:

   ```text
   darwinConfigurations.mac.config.home-manager.users.josh.programs.git.settings.user.email
   ```

   The REPL prints `"josh@joshthomas.dev"`. This value comes from `hosts/mac/home.nix`.

4. Leave the REPL:

   ```text
   :q
   ```

## Add a package

1. Open `home/josh.nix`.
2. Find `home.packages`. Add `cowsay` to the list:

   ```nix
     home.packages = (with pkgs; [
       bun
       cowsay
   ```

3. Apply the change. Enter your password when asked.

   ```sh
   rebuild
   ```

4. Find cowsay:

   ```sh
   command -v cowsay
   ```

   The command prints `/etc/profiles/per-user/josh/bin/cowsay`. cowsay is now installed.

## Roll back

1. Go back to the previous configuration:

   ```sh
   rebuild --rollback
   ```

2. Open a new terminal. Find cowsay:

   ```sh
   command -v cowsay
   ```

   The command prints nothing. The Mac runs the configuration from before your edit, but
   `home/josh.nix` still lists cowsay.

3. Undo the edit:

   ```sh
   jj restore home/josh.nix
   ```

The file and the Mac now match again.

## Next

- [What "Nix" means](nix.md) explains the store, generations and modules.
- [Apply, update and roll back](apply-update-roll-back.md) covers daily changes.
