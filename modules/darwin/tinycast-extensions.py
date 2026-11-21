"""Install Tinycast's extensions from the Raycast Store, and set their preferences
(modules/darwin/tinycast.nix).

Does what Tinycast's own store install does (ExtensionInstaller and ExtensionCatalog.install in
github.com/abue-ammar/tinycast): look the extension up, download the zip that the store built,
copy the manifest, the built commands, assets/ and node_modules/ into the extensions directory,
and record the store's commit in extension-versions.json, so that Tinycast updates it. An
extension that is already installed is left alone: Tinycast keeps it up to date.

The preferences, and the secrets that opnix writes, go into the extension's file in
extension-data/, which keeps its other keys (local storage, caches). A key that the
configuration does not name stays as the app set it.

Tinycast reads all of these at launch and keeps them in memory, so a running Tinycast is quit
before a change and opened again after. Nothing changes, and Tinycast keeps running, when all
is already as configured.

usage: tinycast-extensions.py CONFIG.json
  CONFIG.json: {"extensions": ["HANDLE/NAME", ...],
                "preferences": {NAME: {KEY: {"string" | "bool": VALUE}}},
                "secrets": {NAME: {KEY: PATH}}}
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

SUPPORT = os.path.expanduser("~/Library/Application Support/com.abueammar.tinycast")
EXTENSIONS = os.path.join(SUPPORT, "extensions")
VERSIONS = os.path.join(SUPPORT, "extension-versions.json")
APP = "/Applications/Tinycast.app"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "tinycast-extensions"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def manifest_root(directory):
    if os.path.exists(os.path.join(directory, "package.json")):
        return directory
    for child in sorted(os.listdir(directory)):
        path = os.path.join(directory, child)
        if os.path.exists(os.path.join(path, "package.json")):
            return path
    raise RuntimeError("the store's zip has no package.json")


def install(handle, name, workspace):
    listing = json.loads(fetch(f"https://www.raycast.com/api/v1/extensions/{handle}/{name}"))
    if listing.get("status") not in (None, "active"):
        raise RuntimeError(f"the store lists it as {listing.get('status')}")
    archive = os.path.join(workspace, "extension.zip")
    with open(archive, "wb") as f:
        f.write(fetch(listing["download_url"]))
    expanded = os.path.join(workspace, "expanded")
    subprocess.run(["/usr/bin/ditto", "-x", "-k", archive, expanded], check=True)
    source = manifest_root(expanded)

    with open(os.path.join(source, "package.json")) as f:
        manifest = json.load(f)
    built = [
        f"{c['name']}.js"
        for c in manifest.get("commands", [])
        if os.path.exists(os.path.join(source, f"{c['name']}.js"))
    ]
    if not built:
        raise RuntimeError("the store's zip has no built commands")

    destination = os.path.join(EXTENSIONS, manifest["name"].replace("/", "-"))
    staging = os.path.join(workspace, "staging")
    os.makedirs(staging)
    for file in ["package.json", *built]:
        shutil.copy2(os.path.join(source, file), staging)
    for directory in ("assets", "node_modules"):
        if os.path.isdir(os.path.join(source, directory)):
            shutil.copytree(os.path.join(source, directory), os.path.join(staging, directory))
    shutil.rmtree(destination, ignore_errors=True)
    shutil.move(staging, destination)
    return manifest["name"], listing.get("commit_sha")


def running():
    return subprocess.run(["/usr/bin/pgrep", "-xq", "Tinycast"]).returncode == 0


def preferences_file(name):
    return os.path.join(SUPPORT, "extension-data", f"{name}.json")


def preference_changes(config):
    """The extensions whose stored preferences differ from the configuration, with the new store."""
    wanted = {}
    for name, values in config["preferences"].items():
        wanted.setdefault(name, {}).update(values)
    for name, paths in config["secrets"].items():
        for key, path in paths.items():
            try:
                with open(path) as f:
                    value = f.read().strip()
            except OSError:
                print(f"tinycast: {path} is not there yet; opnix writes it", file=sys.stderr)
                continue
            wanted.setdefault(name, {})[key] = {"string": value}

    changes = {}
    for name, values in wanted.items():
        try:
            with open(preferences_file(name)) as f:
                store = json.load(f)
        except (FileNotFoundError, ValueError):
            store = {}
        stored = store.setdefault("preferences", {})
        new = {key: {kind: {"_0": value} for kind, value in typed.items()} for key, typed in values.items()}
        if any(stored.get(key) != value for key, value in new.items()):
            stored.update(new)
            changes[name] = store
    return changes


def main():
    with open(sys.argv[1]) as f:
        config = json.load(f)
    missing = [
        entry.split("/", 1)
        for entry in config["extensions"]
        if not os.path.exists(os.path.join(EXTENSIONS, entry.split("/", 1)[1], "package.json"))
    ]
    changes = preference_changes(config)
    if not missing and not changes:
        return

    # Tinycast holds both in memory and writes them back, so it must not run meanwhile.
    was_running = running()
    if was_running:
        subprocess.run(["/usr/bin/osascript", "-e", 'quit app "Tinycast"'], check=False)
        for _ in range(50):
            if not running():
                break
            subprocess.run(["/bin/sleep", "0.2"])
        changes = preference_changes(config)

    failed = 0
    if missing:
        os.makedirs(EXTENSIONS, exist_ok=True)
        try:
            with open(VERSIONS) as f:
                versions = json.load(f)
        except (FileNotFoundError, ValueError):
            versions = {}
        for handle, name in missing:
            try:
                with tempfile.TemporaryDirectory() as workspace:
                    installed, sha = install(handle, name, workspace)
                versions[installed] = {"commitSHA": sha} if sha else {}
                print(f"tinycast: installed {handle}/{name}")
            except Exception as error:  # one failed extension must not stop the others
                failed += 1
                print(f"tinycast: could not install {handle}/{name}: {error}", file=sys.stderr)
        write_json(VERSIONS, versions)

    for name, store in changes.items():
        os.makedirs(os.path.dirname(preferences_file(name)), exist_ok=True)
        write_json(preferences_file(name), store)
        print(f"tinycast: wrote the preferences of {name}")

    if was_running:
        subprocess.run(["/usr/bin/open", "-g", APP], check=False)
    if failed:
        print("tinycast: run 'rebuild' again to retry", file=sys.stderr)


def write_json(path, value):
    with open(path + ".tmp", "w") as f:
        os.fchmod(f.fileno(), 0o600)
        json.dump(value, f, separators=(",", ":"))
    os.replace(path + ".tmp", path)


main()
