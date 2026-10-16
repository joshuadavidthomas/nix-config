#!/usr/bin/env bash
# Moves lab boxes from yonder's old Fly coordinator to its coordinator on Cloudflare, once
# (docs/yonder.md). Run it on the Mac, in ~/.nix-config, on main:
#
#   scripts/yonder-move.sh               # lab-1, lab-2 and lab-3, one at a time
#   scripts/yonder-move.sh lab-2         # one box
#
# For each box: check its coordinator.env, remove the binaries deploy.sh left in
# /var/lib/yonder/bin (so it runs the yonder pinned in flake.lock), apply with colmena, and
# start yonderd once with -leave-fabric, through a drop-in in /run that a reboot also
# removes. Then remove the drop-in and restart yonderd without the flag. A box that has
# moved already is skipped, and a box that stopped halfway is finished by running the script
# again. Running VMs keep running: each is its own unit.
set -euo pipefail

coordinator=https://yonder.joshthomas.dev
boxes=("$@")
[ ${#boxes[@]} -gt 0 ] || boxes=(lab-1 lab-2 lab-3)

dropin=/run/systemd/system/yonderd.service.d/yonder-move.conf
start=/run/yonder-move-start

# Runs a command on the box as root. The command goes to bash on stdin, not through the
# login shell, which is fish.
on() { local b=$1; shift; ssh "$b" sudo -n bash -s <<<"$*"; }

# yonderd's log lines that say which fabric a box is in, newest last.
membership() { on "$1" "journalctl -u yonderd -o cat --no-pager | grep -E 'msg=\"(fabric membership|joined the fabric)\"' | tail -n 1"; }

move() {
  local b=$1
  echo "== $b"
  if ! on "$b" "test -s /etc/yonder/coordinator.env"; then
    echo "$b: no /etc/yonder/coordinator.env. See docs/yonder.md#the-files-on-each-box." >&2
    return 1
  fi
  if membership "$b" | grep -qF "coordinator=$coordinator" && ! on "$b" "test -e $dropin"; then
    echo "$b: a member of $coordinator already"
    return 0
  fi

  on "$b" "rm -f /var/lib/yonder/bin/yonderd /var/lib/yonder/bin/yonder"
  # yonderd's own ExecStart, read from its unit when it starts, so it is the one this
  # apply installs, with -leave-fabric. The unit keeps the rest: its environment file,
  # PATH and restarts.
  on "$b" "cat > $start <<'EOF'
#!/bin/sh
while IFS= read -r line; do
  case \$line in ExecStart=*) exec \${line#ExecStart=} -leave-fabric ;; esac
done < /etc/systemd/system/yonderd.service
echo 'yonder-move: no ExecStart in yonderd.service' >&2
exit 1
EOF
chmod 0755 $start
mkdir -p ${dropin%/*}
printf '[Service]\nExecStart=\nExecStart=$start\n' > $dropin
systemctl daemon-reload"

  local since started
  since=$(on "$b" "date +%s")
  started=$(on "$b" "systemctl show yonderd -p ExecMainStartTimestampMonotonic --value")
  colmena apply --on "$b"
  # The apply restarts yonderd when its unit changed. When it did not (the script runs
  # again after it stopped), restart it here.
  if [ "$(on "$b" "systemctl show yonderd -p ExecMainStartTimestampMonotonic --value")" = "$started" ]; then
    on "$b" "systemctl restart yonderd"
  fi

  echo "$b: waiting for yonderd to join $coordinator"
  local log=""
  for _ in $(seq 120); do
    log=$(on "$b" "journalctl -u yonderd -o cat --no-pager --since @$since")
    grep -F 'msg="joined the fabric"' <<<"$log" | grep -qF "coordinator=$coordinator" && break
    log=""
    sleep 1
  done
  if [ -z "$log" ]; then
    echo "$b: yonderd did not join in 2 minutes. Its log:" >&2
    on "$b" "journalctl -u yonderd -o cat --no-pager --since @$since | tail -n 30" >&2
    echo "$b: -leave-fabric stays on until you run this again, or the box restarts." >&2
    return 1
  fi
  grep -E 'msg="(leaving the fabric|joined the fabric)' <<<"$log"

  # Without the flag from here on: yonderd restarts once more, and stays a member.
  on "$b" "rm -f $dropin $start && systemctl daemon-reload"
  on "$b" "systemctl restart yonderd"
  for _ in $(seq 30); do on "$b" "yonder status" >/dev/null 2>&1 && break; sleep 1; done
  if on "$b" "systemctl show yonderd -p ExecStart --value" | grep -q -- -leave-fabric; then
    echo "$b: yonderd still has -leave-fabric" >&2
    return 1
  fi
  # This start's lines only: the one before it left the fabric a moment ago.
  # shellcheck disable=SC2016 # the box expands the invocation
  if on "$b" 'journalctl -o cat --no-pager _SYSTEMD_INVOCATION_ID=$(systemctl show yonderd -p InvocationID --value)' |
    grep -E 'leaving the fabric|start it once'; then
    echo "$b: yonderd did not start as a member" >&2
    return 1
  fi
  on "$b" "yonder status"
  echo "$b: moved"
}

for b in "${boxes[@]}"; do move "$b"; done
