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
volume_gb=20

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

# Put each local_path file's contents into the config. flyctl reads local_path itself, but on
# an update it keeps the contents it sent before for every file that already exists, so a
# changed file would not reach the machine.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config=$tmp/machine.json # flyctl takes a config file only by a .json name
cp machine.json "$config"
for path in $(jq -r '.. | objects | .local_path? // empty' machine.json); do
  base64 < "$path" | tr -d '\n' > "$tmp/file.b64"
  jq --arg p "$path" --rawfile v "$tmp/file.b64" \
    '(.. | objects | select(.local_path? == $p)) |= (del(.local_path) + {raw_value: $v})' \
    "$config" > "$tmp/next.json"
  mv "$tmp/next.json" "$config"
done

id=$(machine_id)
if [ -n "$id" ]; then
  # Update through the Machines API, not `fly machine update`: flyctl decodes the file over the
  # old config, so a container inherits every setting it leaves out from the container that was
  # in its place before. Here the containers replace the old ones as a whole; the mount and the
  # VM size stay.
  token=${FLY_API_TOKEN:-$("$fly" auth token 2>/dev/null)}
  api=https://api.machines.dev/v1/apps/$app/machines/$id
  curl -fsS -H "Authorization: Bearer $token" "$api" \
    | jq --slurpfile new "$config" '{config: (.config + $new[0])}' > "$tmp/body.json"
  version=$(curl -fsS -X POST -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
    --data @"$tmp/body.json" "$api" | jq -r .instance_id)
  echo "Updating machine $id to version $version"

  # Fly reverts an update that can't start, and says so only in the machine's events.
  for _ in $(seq 60); do
    sleep 5
    status=$(curl -fsS -H "Authorization: Bearer $token" "$api")
    reason=$(jq -r --arg v "$version" \
      'first(.events[] | select(.type == "revert" and .request.failed_version == $v) | .request.reason) // empty' <<<"$status")
    if [ -n "$reason" ]; then
      echo "Fly reverted the update: $reason" >&2
      exit 1
    fi
    if jq -e --arg v "$version" '.instance_id == $v and .state == "started"
        and all(.containers[]; .state == "healthy" or .state == "stopped")' <<<"$status" >/dev/null; then
      jq -r '.containers[] | "  \(.name): \(.state)"' <<<"$status"
      exit 0
    fi
  done
  echo "Not every container is healthy after 5 minutes:" >&2
  jq -r '.containers[] | "  \(.name): \(.state)"' <<<"$status" >&2
  exit 1
fi

if ! "$fly" volumes list -a "$app" --json | jq -e --arg v "$volume" 'any(.[]; .name == $v)' >/dev/null; then
  "$fly" volumes create "$volume" -a "$app" --region "$region" --size "$volume_gb" --yes
fi
"$fly" machine run --machine-config "$config" --volume "$volume:/data" --vm-memory 1024 \
  --name monitor --region "$region" -a "$app"
