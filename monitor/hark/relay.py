"""Relay from Alertmanager to hark, on the monitor (monitor/machine.json, docs/monitor.md).

Alertmanager posts each group of alerts to its webhook as one JSON document, and hark takes
its own JSON (https://hark.ryan.ceo/docs), so this rewrites one into the other. It listens on
127.0.0.1:9099. When hark refuses, it answers 502, so Alertmanager tries again; the
Idempotency-Key keeps a retry from reaching the phone twice.
"""

import hashlib
import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HARK_URL = os.environ["HARK_WEBHOOK_URL"]
# Grafana, registered as a hark app: a tap opens the alerts page inside hark, not in Safari
HARK_APP_ID = os.environ.get("HARK_APP_ID")
ALERTS_PAGE = "https://monitor.tail014d2.ts.net/alerting/list"


def to_hark(group):
    labels = group.get("commonLabels", {})
    title = labels.get("alertname", "Alert")
    if "instance" in labels:
        title += f" on {labels['instance']}"
    lines = []
    for alert in group["alerts"]:
        line = alert.get("annotations", {}).get("summary") or alert["labels"].get("alertname", "")
        lines.append(("Resolved: " if alert["status"] == "resolved" else "") + line)
    resolved = group["status"] == "resolved"
    message = {
        "summary": (("Resolved: " if resolved else "") + title)[:500],
        "body": "\n".join(lines)[:8000] or title,
        "url": ALERTS_PAGE,
    }
    if HARK_APP_ID:
        message["appId"] = HARK_APP_ID
    return message


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
        request = urllib.request.Request(
            HARK_URL,
            data=json.dumps(to_hark(group)).encode(),
            headers={"Content-Type": "application/json", "Idempotency-Key": idempotency_key(group)},
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                print(f"sent {group['status']} {group.get('groupKey')}: {response.read().decode()}", flush=True)
                status = 200
        except OSError as error:  # URLError, HTTPError and timeouts are all OSErrors
            detail = error.read().decode() if isinstance(error, urllib.error.HTTPError) else ""
            print(f"hark refused {group.get('groupKey')}: {error} {detail}", flush=True)
            status = 502
        self.send_response(status)
        self.end_headers()

    def log_message(self, *args):  # one line per alert from do_POST is enough
        pass


ThreadingHTTPServer(("127.0.0.1", 9099), Relay).serve_forever()
