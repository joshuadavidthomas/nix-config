# First steps with Nix

In this tutorial we'll use Nix on a Mac that's already set up from this repo. We'll run a
program without installing it, find where it lives, read a value out of the Mac's
configuration, add a package to that configuration, and then roll the change back. It takes
about fifteen minutes, and at the end the Mac is exactly as it started.

You need a terminal and your Mac password (for `rebuild`).

## Run a program without installing it

Run `cowsay`:

```sh
nix run nixpkgs#cowsay -- hello
```

A cow says hello. The first run downloads cowsay, so it takes a few seconds; run it again
and it's instant. Check whether it's installed:

```sh
command -v cowsay
```

Nothing is printed. Nix fetched cowsay and ran it, but didn't put it on your PATH.

## Find where it lives

Start a shell that has cowsay on its PATH:

```sh
nix shell nixpkgs#cowsay
command -v cowsay
```

This time you get a path like `/nix/store/…-cowsay-3.8.4/bin/cowsay`. Every package lives in
its own directory under `/nix/store`, named by a hash of everything that went into building
it. See what cowsay needs:

```sh
nix path-info -rsSh nixpkgs#cowsay
```

That lists cowsay and each store path it depends on, with sizes. Leave the shell:

```sh
exit
```

`command -v cowsay` prints nothing again.

## Read the Mac's configuration

The whole Mac is described by this repo. Open it in the Nix REPL:

```sh
cd ~/.nix-config
nix repl
```

At the `nix-repl>` prompt, load the repo, then ask for your git email:

```text
:lf .
darwinConfigurations.mac.config.home-manager.users.josh.programs.git.settings.user.email
```

The REPL prints `"josh@joshthomas.dev"`. That value comes from `hosts/mac/home.nix`. Press Tab
partway through a name to see what's available at each level. Leave with `:q`.

## Add a package

Open `home/josh.nix` and find `home.packages`. Add `cowsay` to the list:

```nix
  home.packages = (with pkgs; [
    bun
    cowsay
```

Apply it:

```sh
rebuild
```

It asks for your password, builds the new configuration and switches to it. Now:

```sh
command -v cowsay
```

prints `/etc/profiles/per-user/josh/bin/cowsay`, and `cowsay hi` works in any terminal.

## Roll back

Every `rebuild` keeps the previous configuration. Switch back to it:

```sh
rebuild --rollback
```

Open a new terminal and run `command -v cowsay`. It's gone, even though `home/josh.nix` still
lists it. The rollback switched to the configuration from before your edit.

Now undo the edit itself:

```sh
jj restore home/josh.nix
```

The file and the running system agree again, and the Mac is as it was when you started.

## What we did

We ran a program straight from nixpkgs, found it in `/nix/store`, read a setting out of the
Mac's configuration with the REPL, changed that configuration, and rolled it back. From here:

- [About Nix](../explanation/nix.md) explains the store, generations and modules that made
  each of these steps work.
- [Apply, update and roll back](../how-to/apply-update-roll-back.md) covers day-to-day changes
  on every machine.
