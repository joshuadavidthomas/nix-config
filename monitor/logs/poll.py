"""The monitor's own logs into VictoriaLogs, next to the lab boxes' (docs/monitor.md).

Every 10 s this asks Fly's logs API, the one `fly logs` uses, for the monitor app's lines since
the last time, with a read-only token (FLY_LOG_TOKEN), and sends them to VictoriaLogs as
host=monitor, container=<name>. Fly's records don't say which container wrote a line, so the
name comes from each program's line format. Its place in the stream is kept on the volume, so
a restart neither repeats nor skips lines.

Not Fly's log stream (NATS) with Vector, as Fly's log shipper does: it refused the read-only
token ("authorization violation") in every form.
"""

import json
import os
import re
import signal
import sys
import time
import urllib.parse
import urllib.request

APP = "homelab-monitor-joshthomasdev"
TOKEN = os.environ["FLY_LOG_TOKEN"]
STATE = os.environ.get("LOGS_STATE_FILE", "/data/logs/next_token")
VICTORIALOGS = os.environ.get("VICTORIALOGS_URL", "http://127.0.0.1:9428") + (
    "/insert/jsonline?_stream_fields=host,container&_msg_field=message&_time_field=timestamp"
)

CONTAINERS = [  # first match wins
    ("hark", lambda m: m.startswith("relay: ")),
    ("logs", lambda m: m.startswith("logs: ")),
    ("grafana", lambda m: "logger=" in m or "caller=logger.go" in m),
    ("vmalert", lambda m: "app/vmalert" in m),
    # VictoriaLogs uses VictoriaMetrics' libraries as a module, so its paths have "@v1..."
    ("victorialogs", lambda m: "VictoriaLogs" in m or "VictoriaMetrics@" in m),
    ("victoriametrics", lambda m: "VictoriaMetrics/" in m),
    ("alertmanager", lambda m: re.match(r"time=\S+ level=\S+ source=", m)),
    ("tailscale", lambda m: re.match(r"(boot: |\d{4}/\d\d/\d\d \d\d:\d\d:\d\d |logpolicy|iptables|Warning: Extension|Try `iptables|TPM: )", m)
        or "DNS config" in m),
    # the relay or this poller stopping: the line doesn't say which
    ("python", lambda m: m.startswith(("Traceback", "KeyboardInterrupt", "  File \"")) ),
    # Fly's machine: its agent (pilot), Firecracker, the kernel, the volume's check
    ("fly", lambda m: re.match(r"\s*(INFO|WARN|ERROR|DEBUG) |(hallpass|api_proxy): |\[\s*\d+\.\d+\] |/dev/", m)
        or re.search(r"\[\w+:main\] |VMM|Firecracker", m)
        or " container " in m or m.startswith("containers ")),
]


def container(message):
    plain = re.sub(r"\x1b\[[0-9;]*m", "", message)  # Fly's agent colors its lines
    return next((name for name, test in CONTAINERS if test(plain)), "other")


def provider(attributes):
    return ((attributes.get("meta") or {}).get("event") or {}).get("provider")


def fetch(next_token):
    query = urllib.parse.urlencode({"next_token": next_token}) if next_token else ""
    request = urllib.request.Request(
        f"https://api.fly.io/api/v1/apps/{APP}/logs?{query}",
        # the token goes in as it is ("FlyV1 fm2_..."); with "Bearer" Fly refuses it
        headers={"Authorization": TOKEN, "User-Agent": "homelab-monitor-logs"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def ship(entries):
    lines = []
    for entry in entries:
        attributes = entry["attributes"]
        message = attributes.get("message", "")
        lines.append(json.dumps({
            "timestamp": attributes["timestamp"],
            "message": message,
            "level": attributes.get("level", ""),
            "host": "monitor",
            # Fly's own records (pulling images, the volume) come from its runner, not the app
            "container": container(message) if provider(attributes) in ("app", None) else "fly",
        }))
    # Without a content type, urllib sends form data, which VictoriaLogs answers 200 and drops
    request = urllib.request.Request(
        VICTORIALOGS,
        data="\n".join(lines).encode(),
        headers={"Content-Type": "application/stream+json"},
    )
    urllib.request.urlopen(request, timeout=30).close()


def main():
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    try:
        with open(STATE) as f:
            next_token = f.read().strip()
    except OSError:
        next_token = ""
    while True:
        try:
            page = fetch(next_token)
            entries = page.get("data") or []
            if entries and next_token:  # without a saved place, start from now
                ship(entries)
            next_token = (page.get("meta") or {}).get("next_token") or next_token
            with open(STATE, "w") as f:
                f.write(next_token)
            if len(entries) == 100:  # a full page: more are waiting
                continue
        except (OSError, ValueError) as error:
            print(f"logs: {error}", flush=True)
        time.sleep(10)


# Fly stops a container with a signal; exit quietly instead of printing a traceback into the logs
for stop in (signal.SIGINT, signal.SIGTERM):
    signal.signal(stop, lambda *_: sys.exit(0))
main()
