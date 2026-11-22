"""Install Helium's extensions and set its settings in the Default profile
(modules/darwin/helium.nix).

The extensions: one file per extension in External Extensions, which Helium reads at launch. It
then downloads the extension from the Chrome Web Store and updates it from there. Google offers
the download only with the browser's version in the request, so the update URL names the
Chromium version of the installed Helium. An extension that was installed from the store itself
gets no file, and the file of an extension that leaves the list is removed, so Helium removes
that extension.

The settings: the keys of the profile's Preferences that the configuration names. Helium keeps
that file in memory and writes it back when it quits, so the file changes only while Helium is
not running. Keys that Helium protects with a signature, such as the search engine, are not
among them: Helium resets a protected key that something else changed.

usage: helium-profile.py CONFIG.json
  CONFIG.json: {"extensions": [ID, ...], "preferences": {KEY: VALUE or {KEY: ...}}}
"""

import json
import os
import subprocess
import sys

SUPPORT = os.path.expanduser("~/Library/Application Support/net.imput.helium")
EXTERNAL = os.path.join(SUPPORT, "External Extensions")
PROFILE = os.path.join(SUPPORT, "Default")
VERSIONS = "/Applications/Helium.app/Contents/Frameworks/Helium Framework.framework/Versions"
STORE = "https://clients2.google.com/service/update2/crx"
INTERNAL = 1  # Chromium's location of an extension installed from the store


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return {}


def write_json(path, value):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".tmp", "w") as f:
        os.fchmod(f.fileno(), 0o600)
        json.dump(value, f, separators=(",", ":"))
    os.replace(path + ".tmp", path)


def chromium_version():
    versions = [v for v in os.listdir(VERSIONS) if v != "Current"]
    if len(versions) != 1:
        raise RuntimeError(f"expected one version in {VERSIONS}, found {versions}")
    return versions[0]


def from_store(extension_id):
    for name in ("Secure Preferences", "Preferences"):
        settings = read_json(os.path.join(PROFILE, name)).get("extensions", {}).get("settings", {})
        if settings.get(extension_id, {}).get("location") == INTERNAL:
            return True
    return False


def extensions(ids):
    wanted = {
        extension_id: {"external_update_url": f"{STORE}?prodversion={chromium_version()}"}
        for extension_id in ids
        if not from_store(extension_id)
    }
    os.makedirs(EXTERNAL, exist_ok=True)
    for file in os.listdir(EXTERNAL):
        if file.endswith(".json") and file[: -len(".json")] not in wanted:
            os.remove(os.path.join(EXTERNAL, file))
            print(f"helium: removed {file[: -len('.json')]} from the extensions")
    for extension_id, source in wanted.items():
        path = os.path.join(EXTERNAL, f"{extension_id}.json")
        if read_json(path) != source:
            write_json(path, source)
            print(f"helium: added {extension_id} to the extensions")


def merge(store, wanted):
    """Puts the values of wanted into store; True if store changed."""
    changed = False
    for key, value in wanted.items():
        if isinstance(value, dict):
            if not isinstance(store.get(key), dict):
                store[key] = {}
            changed |= merge(store[key], value)
        elif store.get(key) != value:
            store[key] = value
            changed = True
    return changed


def preferences(wanted):
    path = os.path.join(PROFILE, "Preferences")
    store = read_json(path)
    if not merge(store, wanted):
        return
    if subprocess.run(["/usr/bin/pgrep", "-xq", "Helium"]).returncode == 0:
        print("helium: quit Helium and run 'rebuild' again to apply its settings", file=sys.stderr)
        return
    write_json(path, store)
    print("helium: wrote its settings")


def main():
    config = read_json(sys.argv[1])
    extensions(config["extensions"])
    preferences(config["preferences"])


main()
