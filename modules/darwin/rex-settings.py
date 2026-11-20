"""Write Rex for Mac's server list and custom themes (modules/darwin/rex.nix).

Rex keeps both as JSON in data values of its defaults domain, which home-manager's
targets.darwin.defaults cannot write. Each server keeps the fields that the app learns when it
connects (lastHostID, lastInstanceID), so a switch does not reset them.

usage: rex-settings.py SERVERS.json THEMES.json
"""

import json
import plistlib
import subprocess
import sys

DOMAIN = "com.superlogical.rex"
LEARNED = ("lastHostID", "lastInstanceID")


def current():
    out = subprocess.run(
        ["/usr/bin/defaults", "export", DOMAIN, "-"], capture_output=True, check=True
    ).stdout
    return plistlib.loads(out) if out.strip() else {}


def write(prefs, key, value):
    data = json.dumps(value, separators=(",", ":")).encode()
    old = prefs.get(key)
    if isinstance(old, bytes):
        try:
            if json.loads(old) == value:
                return
        except ValueError:
            pass
    subprocess.run(
        ["/usr/bin/defaults", "write", DOMAIN, key, "-data", data.hex()], check=True
    )
    print(f"rex: wrote {key}")


def main():
    servers_path, themes_path = sys.argv[1:3]
    with open(servers_path) as f:
        servers = json.load(f)
    with open(themes_path) as f:
        themes = json.load(f)

    prefs = current()
    learned = {}
    old = prefs.get("RexSync.servers")
    if isinstance(old, bytes):
        try:
            for record in json.loads(old).get("records", []):
                learned[record.get("id")] = {k: record[k] for k in LEARNED if k in record}
        except ValueError:
            pass

    records = [{**server, **learned.get(server["id"], {})} for server in servers]
    write(prefs, "RexSync.servers", {"formatVersion": 1, "records": records})
    write(prefs, "Workspace.customThemes", themes)


main()
