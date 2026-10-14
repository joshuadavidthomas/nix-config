"""Relay from Alertmanager to hark, on the monitor (monitor/machine.json, docs/monitor.md).

Alertmanager posts each group of alerts to its webhook as one JSON document, and hark takes
its own JSON (https://hark.ryan.ceo/docs), so this rewrites one into the other. It listens on
127.0.0.1:9099. When hark refuses, it answers 502, so Alertmanager tries again; the
Idempotency-Key keeps a retry from reaching the phone twice.

POST /heartbeat is the always-firing Watchdog, about every minute. It goes on to the heartbeat
Worker on Cloudflare (monitor/heartbeat), which tells hark when the pings stop. Sending it
through here means a dead relay stops the heartbeat too.
"""

import hashlib
import json
from datetime import datetime
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HARK_URL = os.environ["HARK_WEBHOOK_URL"]
# Grafana, registered as a hark app: a tap opens the alerts page inside hark, not in Safari
HARK_APP_ID = os.environ.get("HARK_APP_ID")
ALERTS_PAGE = "https://monitor.tail014d2.ts.net/alerting/list"
HEARTBEAT_URL = os.environ.get("HEARTBEAT_URL")
HEARTBEAT_TOKEN = os.environ.get("HEARTBEAT_TOKEN")
# Cloudflare refuses urllib's own User-Agent (Python-urllib) with error 1010
USER_AGENT = "homelab-monitor-relay"


def to_hark(group):
    """The phone shows title in bold (the box, or Homelab) and summary under it; body is for
    the app. Each rule has a summary for when it fires and a resolved for when it ends."""
    labels = group.get("commonLabels", {})
    firing = [a for a in group["alerts"] if a["status"] == "firing"]
    resolved = [a for a in group["alerts"] if a["status"] == "resolved"]
    lines = [describe(a) for a in firing + resolved]
    shown = firing or resolved
    summary = lines[0] if len(shown) == 1 else f"{len(shown)} alerts: " + "; ".join(lines[: len(shown)])
    return {
        "title": labels.get("instance", "Homelab")[:80],
        "summary": summary[:500],
        "body": "\n".join(f"{a['labels'].get('alertname', 'Alert')}: {line}" for a, line in zip(firing + resolved, lines))[:8000]
        or summary,
        "url": ALERTS_PAGE,
        **({"appId": HARK_APP_ID} if HARK_APP_ID else {}),
    }


def describe(alert):
    annotations = alert.get("annotations", {})
    summary = annotations.get("summary") or alert["labels"].get("alertname", "Alert")
    if alert["status"] == "firing":
        return summary
    lasted = duration(alert["startsAt"], alert.get("endsAt"))
    return f"{annotations.get('resolved') or 'Resolved: ' + summary}, after {lasted}"


def duration(starts_at, ends_at):
    try:
        seconds = (parse_time(ends_at) - parse_time(starts_at)).total_seconds()
    except (TypeError, ValueError):
        return "a while"
    minutes = max(1, round(seconds / 60))
    return f"{minutes} min" if minutes < 120 else f"{round(minutes / 60)} h"


def parse_time(value):
    # Alertmanager sends RFC 3339 with up to nanoseconds; fromisoformat takes microseconds
    date, _, rest = value.rstrip("Z").partition(".")
    fraction = "".join(c for c in rest if c.isdigit())[:6]
    return datetime.fromisoformat(f"{date}.{fraction or '0'}+00:00")


def idempotency_key(group):
    alerts = sorted(
        (a["fingerprint"], a["status"], a["startsAt"], a.get("endsAt", "")) for a in group["alerts"]
    )
    return hashlib.sha256(json.dumps([group.get("groupKey"), alerts]).encode()).hexdigest()


class Relay(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200 if self.path == "/health" else 404)
        self.end_headers()

    def do_POST(self):
        group = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path == "/heartbeat":
            self.reply(self.forward_heartbeat())
            return
        request = urllib.request.Request(
            HARK_URL,
            data=json.dumps(to_hark(group)).encode(),
            headers={
                "Content-Type": "application/json",
                "Idempotency-Key": idempotency_key(group),
                "User-Agent": USER_AGENT,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                print(f"sent {group['status']} {group.get('groupKey')}: {response.read().decode()}", flush=True)
                status = 200
        except OSError as error:  # URLError, HTTPError and timeouts are all OSErrors
            detail = error.read().decode() if isinstance(error, urllib.error.HTTPError) else ""
            print(f"hark refused {group.get('groupKey')}: {error} {detail}", flush=True)
            status = 502
        self.reply(status)

    def forward_heartbeat(self):
        if not HEARTBEAT_URL:
            return 200
        request = urllib.request.Request(
            HEARTBEAT_URL,
            method="POST",
            headers={"Authorization": f"Bearer {HEARTBEAT_TOKEN}", "User-Agent": USER_AGENT},
        )
        try:
            with urllib.request.urlopen(request, timeout=15):
                return 200
        except OSError as error:
            print(f"heartbeat failed: {error}", flush=True)
            return 502

    def reply(self, status):
        self.send_response(status)
        self.end_headers()

    def log_message(self, *args):  # one line per alert from do_POST is enough
        pass


ThreadingHTTPServer(("127.0.0.1", 9099), Relay).serve_forever()
