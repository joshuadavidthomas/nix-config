#!/usr/bin/env bash
# Creates or updates the monitor: one Fly machine with one volume, no public IP
# (docs/monitor.md). Run from anywhere, with flyctl logged in.
#
#   monitor/deploy.sh          create the volume and the machine, or update the machine
#   monitor/deploy.sh status   show the machine, its volume and its IPs (there should be none)
set -euo pipefail

app=homelab-monitor-joshthomasdev
region=dfw
volume=monitor_data
volume_gb=10

cd "$(dirname "$0")" # machine.json's local_path files are relative to here
fly=${FLYCTL:-flyctl}

machine_id() {
  "$fly" machine list -a "$app" --json | jq -r '.[] | select(.name == "monitor") | .id'
}

if [ "${1:-}" = status ]; then
  "$fly" machine list -a "$app"
  "$fly" volumes list -a "$app"
  "$fly" ips list -a "$app"
  exit 0
fi

id=$(machine_id)
if [ -n "$id" ]; then
  "$fly" machine update "$id" -a "$app" --machine-config machine.json --yes
  exit 0
fi

if ! "$fly" volumes list -a "$app" --json | jq -e --arg v "$volume" 'any(.[]; .name == $v)' >/dev/null; then
  "$fly" volumes create "$volume" -a "$app" --region "$region" --size "$volume_gb" --yes
fi
"$fly" machine run --machine-config machine.json --volume "$volume:/data" --vm-memory 1024 \
  --name monitor --region "$region" -a "$app"
