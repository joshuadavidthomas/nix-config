"""Install Tinycast's extensions from the Raycast Store (modules/darwin/tinycast.nix).

Does what Tinycast's own store install does (ExtensionInstaller and ExtensionCatalog.install in
github.com/abue-ammar/tinycast): look the extension up, download the zip that the store built,
copy the manifest, the built commands, assets/ and node_modules/ into the extensions directory,
and record the store's commit in extension-versions.json, so that Tinycast updates it. An
extension that is already installed is left alone: Tinycast keeps it up to date.

Tinycast reads its extensions and extension-versions.json at launch, so a running Tinycast is
quit before an install and opened again after.

usage: tinycast-extensions.py HANDLE/NAME...
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


def main():
    wanted = [arg.split("/", 1) for arg in sys.argv[1:]]
    missing = [
        (handle, name)
        for handle, name in wanted
        if not os.path.exists(os.path.join(EXTENSIONS, name, "package.json"))
    ]
    if not missing:
        return

    was_running = running()
    if was_running:
        subprocess.run(["/usr/bin/osascript", "-e", 'quit app "Tinycast"'], check=False)
        for _ in range(50):
            if not running():
                break
            subprocess.run(["/bin/sleep", "0.2"])

    os.makedirs(EXTENSIONS, exist_ok=True)
    try:
        with open(VERSIONS) as f:
            versions = json.load(f)
    except (FileNotFoundError, ValueError):
        versions = {}

    failed = 0
    for handle, name in missing:
        try:
            with tempfile.TemporaryDirectory() as workspace:
                installed, sha = install(handle, name, workspace)
            versions[installed] = {"commitSHA": sha} if sha else {}
            print(f"tinycast: installed {handle}/{name}")
        except Exception as error:  # one failed extension must not stop the others
            failed += 1
            print(f"tinycast: could not install {handle}/{name}: {error}", file=sys.stderr)

    with open(VERSIONS + ".tmp", "w") as f:
        json.dump(versions, f, separators=(",", ":"))
    os.replace(VERSIONS + ".tmp", VERSIONS)

    if was_running:
        subprocess.run(["/usr/bin/open", "-g", APP], check=False)
    if failed:
        print("tinycast: run 'rebuild' again to retry", file=sys.stderr)


main()
