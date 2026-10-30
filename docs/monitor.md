# The monitor

The monitor is one Fly machine, `monitor` in the app `homelab-monitor-joshthomasdev`. It
stores the lab boxes' metrics and logs and shows them in Grafana. The design and its reasons
are in [Homelab monitoring](research/homelab-monitoring.md). Its files are in `monitor/`.

## What runs

A multi-container machine: each service is its own container, from its publisher's image, as
in a Docker Compose file. The containers share one network, so they reach each other on
`localhost`, and one Fly volume at `/data`, with a directory for each service.

| Container | Does | Data |
| --- | --- | --- |
| `prepare` | Makes the data directories, then exits | |
| `tailscale` | Joins the tailnet as `monitor`, with the tag `tag:monitor`, and serves Grafana over HTTPS | `/data/tailscale` |
| `victoriametrics` | Metrics, kept 1 year, on port 8428; the volume is 20 GB | `/data/vm` |
| `victorialogs` | Logs, kept 30 days, on port 9428 | `/data/vl` |
| `vmalert` | Evaluates the alert rules in `monitor/vmalert/rules.yml` each 30 s | in VictoriaMetrics |
| `alertmanager` | Groups alerts and sends them to the relay | `/data/alertmanager` |
| `hark` | Rewrites each alert for hark and sends it to your phone (`monitor/hark/relay.py`) | |
| `logs` | The monitor's own logs into VictoriaLogs (`monitor/logs/poll.py`) | `/data/logs` |
| `grafana` | Dashboards, from `monitor/grafana/`, on 127.0.0.1:3000 only; logs warnings and up | `/data/grafana` |

The machine has no public IP and no Fly services, so nothing on the internet can connect to
it. Vector on each lab box sends to it (`modules/nixos/server.nix`) over the tailnet. The tailnet
policy (`tailscale-acls`) lets lab boxes reach only ports 8428 and 9428.

Grafana is at <https://monitor.tail014d2.ts.net>, from your devices. `tailscale serve`
(`monitor/tailscale/serve.json`) answers on port 443 of the tailnet addresses and passes each
request to Grafana. Tailscale gets the certificate from Let's Encrypt and renews it; it is kept
in `/data/tailscale/certs`. The tailnet needs HTTPS certificates turned on (DNS page of the
admin console), which it has. Each certificate is listed in the public Certificate
Transparency logs, so the name `monitor.tail014d2.ts.net` is public; the machine is not.

Other apps in the Fly org can reach it over Fly's private network. They are all yours, and the
lab is a trusted network ([Decisions](decisions.md#network)).

## Deploy

`flyctl` is in `home/`. Log in once with `fly auth login`.

1. Make the monitor's Tailscale client, as in [The Tailscale client](secrets.md#the-tailscale-client),
   but with the tag `tag:monitor`: Settings > Trust credentials, kind OAuth, scope Auth Keys
   (`auth_keys`) with Write. In 1Password, in the vault `dotfiles`, make an item named
   "Homelab monitor Tailscale OAuth" with the field `client secret`.
2. Give its secret to the app. It goes from 1Password to Fly, not through the repo. The
   `tailscale` container adds `?ephemeral=false&preauthorized=true` to it:

   ```sh
   printf 'TS_AUTHKEY=%s\n' "$(op read 'op://dotfiles/Homelab monitor Tailscale OAuth/client secret')" \
     | fly secrets import --stage -a homelab-monitor-joshthomasdev
   ```

   The `logs` container reads the monitor's own logs, and VictoriaMetrics the Fly machine's metrics,
   with a read-only token for the Fly org:

   ```sh
   printf 'FLY_LOG_TOKEN=%s\n' "$(fly tokens create readonly personal)" | fly secrets import --stage -a homelab-monitor-joshthomasdev
   ```

   The secret stays "Staged". Ignore "Deploy secrets" in Fly's dashboard: it works only for apps
   deployed with `fly deploy`. A machine gets the app's secrets when `deploy.sh` runs.

3. Create the volume and the machine:

   ```sh
   monitor/deploy.sh
   ```

4. Check that `monitor` is on the tailnet, and that the app has no IPs:

   ```sh
   tailscale status | grep monitor
   monitor/deploy.sh status
   ```

5. Open <https://monitor.tail014d2.ts.net>, log in as `admin` with the password `admin`, and set a new
   password. Grafana keeps it on the volume.

Orbs cannot reach the monitor. To check it from an orb, SSH to a lab box and query from
there; see [Check what a lab box sends](research/homelab-monitoring.md#check-what-a-lab-box-sends).

## How fresh

| Step | Delay |
| --- | --- |
| Vector reads CPU and clock speed, memory, load, network, disk I/O, each unit's CPU and memory | Every 10 s |
| Vector reads everything else, and SMART | Every 60 s |
| A reading reaches VictoriaMetrics | Seconds |
| Queries see it | After 5 s (`-search.latencyOffset=5s`; the default, 30 s, hid the newest half minute) |
| Grafana draws rates (CPU %, throughput) | Over 40 s: 4 × the 10 s `timeInterval` of the data source |
| Node Exporter Full refreshes | Every 15 s, over the last hour by default |

A rate over 40 s needs a sample in each window, so every counter a dashboard draws as a rate is
in the 10 s set (`liveCollectors` in `modules/nixos/server.nix`). A rate over a window shorter
than the interval reads 0 in VictoriaMetrics, not empty.

## Dashboards

Grafana loads its data sources and dashboards from `monitor/grafana/` at start. Each dashboard
has one job and links to the others; each panel's ⓘ says what it shows.

| Dashboard | For | What it has |
| --- | --- | --- |
| **Homelab**, the home page (`overview.json`) | After an alert: which machine looks off, and what else changed then | A row per machine (reporting, CPU over the last hours, memory, disk, temperature, failed units, Tailscale's warnings, VMs, uptime); CPU, load (as a share of the threads), memory, network and disk I/O over time, with marks for alerts (red), deploys (blue), reboots (purple) and processes killed for memory (orange): a line per machine, the highest on top of the legend, and a click on a line opens that machine; network and disk show the 5 busiest machines, the rest as other, and the total; 7 days of reporting; errors |
| **Capacity** (`capacity.json`) | Room left, and how fast it goes | Each machine's cores, threads, memory and disk, and the share free; days until / is full at last week's rate; drive wear; 30-day trends |
| **VMs** (`vms.json`) | yonder's VMs | Each VM, its machine, when it started, its CPU, memory and traffic; when each ran; CPU and memory per VM; VMs per machine; yonderd |
| **Machine** (`box.json`) | One machine in detail | Hardware (model, CPU, cores and threads, memory, drive, system), live CPU, memory, disk, pressure and temperature, 7 days of reporting, failed units, Tailscale's warnings, CPU by kind and per thread (with its core), clock speed, load, the drive's health and I/O, network, Tailscale's traffic (direct or relayed), VMs, the journal's warnings and errors; the same marks as Homelab. Now, as in btop: each thread's CPU with its last hour, each core's temperature, the clock and load, memory, how full each filesystem is, the network now with its top and total. What is using it: CPU and memory by systemd unit, the 8 largest and the rest, and every unit in a table |
| **Logs** (`logs.json`) | Searching the journals | Lines over time per machine, the loudest sources, and the lines, filtered by machine, level and words |
| **Monitor** (`monitor.json`) | The monitor itself | The heartbeat, the last alert, failed sends, data arriving, the Fly machine's CPU (against its baseline), memory and disk, the volume, Vector's queues, memory per service, Tailscale's traffic, the relay's and the monitor's logs; restarts as marks |
| Node Exporter Full (grafana.com 1860) | Everything node_exporter has | Linked from Machine |

They work for any number of machines, of any kind. Whatever is per machine is a row in a
table, a lane in a timeline or a line in a chart, never one panel for each known machine, so
a new machine appears everywhere once its Vector sends. Each machine's color comes from its
name (Grafana's "by series name" palette), so it is the same in every chart with no list to
keep. A section a machine has no data for stays empty: a machine without SMART data has no
drive health, and only yonder hosts have VMs. They were checked against a fake fleet of ten
machines made from the lab boxes' data, one of them silent.

VictoriaMetrics scrapes the monitor's own services each 30 s for the Monitor dashboard
(`monitor/victoriametrics/scrape.yml`), with `host` and `instance` `monitor`: the stores, vmalert,
Alertmanager, Tailscale's client metrics (`100.100.100.100/metrics`), and the Fly machine's
`fly_instance_*` metrics, federated from Fly's Prometheus with `FLY_LOG_TOKEN`
(`api.fly.io/prometheus/personal/federate`). Logs:
Explore, with the data source VictoriaLogs, or the Logs dashboard. For example
`host:lab-2 _SYSTEMD_UNIT:sshd.service`.

A VM is known by its yonder ID, from its unit `yonder-vm-<ID>.service`. Its traffic is its
TAP's on the host (`yt-` and the ID's last 12 characters), so what the TAP receives the VM sent.
When it started comes from node_exporter's unit start times
(`--collector.systemd.enable-start-time-metrics` in `modules/nixos/server.nix`). Its CPU and memory
are its unit's, below: what the host gives the VM, not what runs in it.

What is using a machine is measured by systemd unit, not by process: each unit's cgroup, read by
Vector's `host_metrics` source with only its `cgroups` collector, every 10 s
(`modules/nixos/server.nix`). It sends `host_cgroup_cpu_usage_seconds_total` and
`host_cgroup_memory_anon_bytes` (the memory a unit holds, not the file cache the kernel can
take back), with the job `units` and the tags `cgroup` (`system.slice/nix-daemon.service`) and
`unit` (`nix-daemon.service`), for each unit in a slice: services, a user's sessions
(`user-1000.slice`, on the dashboards `user 1000`), and each VM. Not the slices, which would count their units
twice. A unit's CPU is in threads' worth: 1 is one thread busy all the time.

Cores and threads: a thread is what the kernel counts as a CPU, and a core with
hyper-threading runs two (a hybrid Intel CPU's efficiency cores run one each). CPU % and
load are shares of the threads. The cores and the CPU's model come from node_exporter's
`node_cpu_info` (`--collector.cpu.info` in `modules/nixos/server.nix`), a series per thread
with its core; a machine without it shows threads only. CPU per thread names each thread
with its core, so a core's two threads read as a pair. The clock speed is node_exporter's
`cpufreq` collector, read each 10 s with the CPU.

The dashboards select by the labels `job` and `instance`, which Vector adds on the lab boxes
(`modules/nixos/server.nix`): `instance` is the box's name, and `job` is `node`, `smartctl`,
`tailscale`, `units` (systemd units, from Vector) or `vector`.

The marks on the graphs: deploys are the journal's "finished switching to system configuration"
lines (each `rebuild` that switches), from VictoriaLogs; a reboot is a machine booted less than 5 minutes
before; out of memory is node_exporter's `oom_kill` count going up. Failed units are units in
systemd's `failed` state now.

Changes made in Grafana are not saved. To change a dashboard or add one, put its JSON in
`monitor/grafana/dashboards/`, add it to the `grafana` container's `files` in
`monitor/machine.json`, and deploy. A dashboard downloaded from grafana.com may name its data
source `${DS_PROMETHEUS}`; replace that with `victoriametrics`, and delete its `__inputs`.

## Logs

| Logs | Where | Read them |
| --- | --- | --- |
| The lab boxes' journals | VictoriaLogs, 30 days | Grafana: the Logs dashboard, errors on Homelab, warnings on Machine, or Explore (`host:lab-2`) |
| The monitor's containers | VictoriaLogs, 30 days | The Logs dashboard (machine monitor, level Everything), or Explore: `host:monitor container:hark` |
| The heartbeat Worker | Cloudflare's Workers Logs | Cloudflare dashboard > Workers > homelab-heartbeat > Logs |
| Inside yonder's VMs | Not collected | ([Decisions](decisions.md#monitoring)) |

The `logs` container asks Fly's logs API, the one `fly logs` uses, every 10 s for the monitor
app's new lines, with a read-only token for the Fly org (the secret `FLY_LOG_TOKEN`, which VictoriaMetrics also uses for the machine's metrics), and sends
them to VictoriaLogs. Its place in the stream is in `/data/logs`, so a restart neither repeats
nor skips lines. Not Fly's log stream (NATS, through Vector, as Fly's log shipper does): it
refused the read-only token in every form ("authorization violation").

Fly's records don't say which container wrote a line, so `poll.py` takes the container's name
from each program's line format (`CONTAINERS`): Grafana's `logger=`, vmalert's `app/vmalert`,
VictoriaLogs' `VictoriaMetrics@v…` library paths, Alertmanager's `time=… level=… source=`,
Tailscale's dated Go lines, the relay's `relay: `, and `fly` for Fly's own machine (its agent,
Firecracker, the kernel, image pulls). The relay and the poller exit quietly on Fly's stop
signal, so no tracebacks. What matches nothing is `other`; in a full stop and start, 3 of
about 360 lines were, before the last patterns.

The Worker can't send to VictoriaLogs, which listens only on the tailnet. It logs state changes
(silence, page, back) and errors to Cloudflare instead (`observability` in `wrangler.jsonc`).

## Alerts

vmalert evaluates `monitor/vmalert/rules.yml` and sends what fires to Alertmanager
(`monitor/alertmanager/alertmanager.yml`), which sends it to hark through a relay
(`monitor/hark/relay.py`). The relay rewrites Alertmanager's JSON into hark's. The phone shows
the sender in bold, the box (`lab-2`, or `Monitor` from the heartbeat), and one line under
it: the rule's `summary` annotation when it fires ("/ is 91 % full") and its `resolved`
annotation when it ends, with how long it lasted ("/ is under 90 % again, after 40 min"). hark
shows `summary` in place of `body`, so `body`, with the alert names, is only in the app. A new
rule needs both annotations, each one short sentence. A tap opens Grafana's alerts
inside hark: Grafana is registered as a hark app (`HARK_APP_ID` in `monitor/machine.json`).
hark gets a second message when an alert resolves, and a repeat each 12 hours while it fires.
The hark webhook URL is the Fly secret `HARK_WEBHOOK_URL`; only the `hark` container gets it.

Three alerts, and the heartbeat's "Monitor silent", are hark **on-call pages** instead
(`urgency: page` in `rules.yml`): with a sound, and repeated after 5 and 15 minutes until you
acknowledge them on the lock screen. hark's server marks pages time-sensitive, but its iOS app
lacks Apple's time-sensitive entitlement, so iOS shows no "Time Sensitive Notifications" switch
for it and treats pages as ordinary: they don't get through a Focus on their own. To let them,
allow Hark in each Focus (Settings > Focus > the Focus > Apps); every hark notification then
gets through, not only pages. Nothing in hark gets past the mute switch (that takes Apple's
Critical Alerts entitlement). Ordinary hark notifications have no sound (hark issue #9), so the
rest arrive silently. When a
paged alert resolves, the relay or the Worker resolves the page with the monitor's own hark
token, `HARK_PAGES_TOKEN` (scopes `oncall:read` and `oncall:write`), and sends the resolved line
as an ordinary notification. The relay keeps the open pages' IDs in `/data/hark/pages.json`.

The on-call group is "Homelab" (`ocg_r281ZmraVfmAQQVW`, `HARK_ONCALL_GROUP`), in the hark team
"Homelab" (`team_ldHosVdZTYzn_E5P`), with you always on call. The service that sends the pages
must belong to someone in that team.

Grafana became a hark app with hark's API. The published `harkctl` (0.4.3) has no `apps`
command, although hark's docs and app show one, so log in with the app scopes and call the
API. The login keeps harkctl's other scopes; the token stays in the config file:

```sh
npx harkctl@latest auth login --client-name "harkctl" \
  --scope notifications:send --scope interactions:create --scope interactions:read \
  --scope activities:read --scope activities:write --scope devices:read \
  --scope services:read --scope services:write --scope apps:read --scope apps:write
cfg="$HOME/Library/Application Support/hark/config.json"
curl -s -X POST "$(jq -r '.apiUrl // "https://hark.ryan.ceo"' "$cfg")/api/agent/apps" \
  -H "Authorization: Bearer $(jq -r .token "$cfg")" -H 'Content-Type: application/json' \
  -d '{"name": "Homelab", "url": "https://monitor.tail014d2.ts.net"}'
```

Every alert goes to your phone, so there are few: each needs a person, soon, and fires rarely.
Trends that can wait, such as drive wear, temperatures, swap and Vector's queues, are on the
dashboards. There is no Discord: a channel that nobody reads is not an alert
([Decisions](decisions.md#monitoring)).

| Alert | When |
| --- | --- |
| `BoxSilent` (page) | A lab box sent no metrics for 5 minutes (3, then 2 more to let a queue catch up). Its other alerts are held back. |
| `DriveFailing`, `DriveCriticalWarning` (pages) | A drive fails its SMART check, or reports an NVMe critical warning |
| `DiskAlmostFull` | A filesystem is over 90 % full for 10 minutes |
| `CoreServiceFailed` | yonderd, the `.internal` resolver (`yonder-resolver.service` or `.socket`), tailscaled, vector, sshd, nix-daemon, systemd-resolved, dhcpcd, opnix-secrets or the SMART exporter failed for 5 minutes |
| `LowMemory` | Under 10 % of memory free for 15 minutes |
| `MonitorVolumeFull` | The monitor's volume is over 85 % full for 30 minutes. At 100 % the stores stop taking data; extend it with `fly volumes extend` |
| `Watchdog` | Always. It is the heartbeat, below. |

In about a month, count how often each alert fired, and whether it needed you. Fix or delete
one that didn't. vmalert keeps the history in VictoriaMetrics, as the series `ALERTS`.

Grafana shows the rules and the firing alerts under Alerting, and silences an alert there
(data source Alertmanager). A silence is kept on the volume.

To change a rule, edit `rules.yml`, check it, and deploy:

```sh
vmalert -rule=monitor/vmalert/rules.yml -dryRun
amtool check-config monitor/alertmanager/alertmanager.yml
```

Both are in nixpkgs (`victoriametrics` and `prometheus-alertmanager`).

To check the path to your phone, send Alertmanager a test alert from inside the machine. hark
gets it within a minute; the relay logs `sent firing … "delivered":1` (`fly logs`):

```sh
fly machine exec <id> -a homelab-monitor-joshthomasdev --container grafana \
  'wget -qO- --header="Content-Type: application/json" --post-data="[{\"labels\":{\"alertname\":\"TestAlert\"},\"annotations\":{\"summary\":\"Test\"}}]" 127.0.0.1:9093/api/v2/alerts'
```

## Heartbeat

A dead monitor can't say it's dead, so a Worker on Cloudflare listens for it
(`monitor/heartbeat`). Alertmanager sends the always-firing `Watchdog` to the relay about every
minute, and the relay sends it on to the Worker's `/ping`, with the token `HEARTBEAT_TOKEN`.
Each ping moves a Durable Object's alarm 5 minutes out. When the pings stop, the alarm fires
and hark gets "Monitor silent", again each 12 hours while it lasts, and "Resolved" with the next
ping. Because the ping goes through the relay, it stops when anything on the way to your phone
stops: the machine, vmalert, Alertmanager or the relay.

The Worker's secrets are `HEARTBEAT_TOKEN` and `HARK_WEBHOOK_URL`; its other settings are in
`monitor/heartbeat/wrangler.jsonc`. The relay gets the Worker's address as `HEARTBEAT_URL` and
the token as the Fly secret `HEARTBEAT_TOKEN`; without an address, it drops the pings.

Set it up once, on the Mac, from the repo:

```sh
# a token for the pings, kept in 1Password
op item create --vault dotfiles --category password --title "Homelab monitor heartbeat" \
  --generate-password='letters,digits,64'
cd monitor/heartbeat
npx wrangler@4.151.0 login
npx wrangler@4.151.0 deploy   # prints the Worker's address
op read 'op://dotfiles/Homelab monitor heartbeat/password' | npx wrangler@4.151.0 secret put HEARTBEAT_TOKEN
op read 'op://dotfiles/Homelab monitor hark/webhook url' | npx wrangler@4.151.0 secret put HARK_WEBHOOK_URL
printf 'HEARTBEAT_TOKEN=%s\n' "$(op read 'op://dotfiles/Homelab monitor heartbeat/password')" \
  | fly secrets import --stage -a homelab-monitor-joshthomasdev
```

`HEARTBEAT_URL` in `monitor/machine.json` is the Worker's address with `/ping`
(<https://homelab-heartbeat.joshthomasdev.workers.dev/ping>), and the `hark` container gets the
Fly secret `HEARTBEAT_TOKEN`. The relay sends its own `User-Agent`: Cloudflare refuses Python's
default one with error 1010 (403), before the Worker sees the request.

After a change to the Worker, deploy it again from `monitor/heartbeat` with
`npx wrangler@4.151.0 deploy`; its secrets stay.

To test it locally, `npx wrangler@4.151.0 dev --var SILENT_AFTER_SECONDS:5 ...` runs the Worker
and its alarm on your machine.

## Change it

Edit `monitor/machine.json` or the files next to it, then run `monitor/deploy.sh` again. Each
deploy restarts every container; Grafana's users and password, Alertmanager's silences and the
data are on the volume and stay.

When the machine exists, `deploy.sh` updates it through the Machines API, not with
`fly machine update`, and waits until every container is healthy. flyctl decodes the file over
the old config, which goes wrong in two ways:

- A container inherits each setting it leaves out from the container that was in its place
  before. When vmalert was added before Grafana, it got Grafana's entrypoint and variables.
- A file that the machine already has keeps the contents flyctl sent before.

`deploy.sh` also puts the contents of each `local_path` file into the config itself.

Fly reverts an update that cannot start, for example one that names a secret the app doesn't
have, and records the reason only in the machine's events. `deploy.sh` reports it and fails.

To update a service, change its image tag. Use a tag, not a digest: Fly does not take
`tag@digest`.

## Look inside

`fly ssh` needs a WireGuard tunnel. `fly machine exec` goes through Fly's API:

```sh
fly machine exec <id> -a homelab-monitor-joshthomasdev --container grafana 'wget -qO- localhost:8428/health'
```

The state of each container:

```sh
fly machine status <id> -a homelab-monitor-joshthomasdev
```

Grafana writes most of the log, so `fly logs` shows the other containers' lines only for a
short time.

## If it stops

- **The machine stays at "VMM up, configuring containers" and no container starts.** A
  health check is missing a field. Each check needs `kind`, `interval`, `timeout`,
  `grace_period`, `failure_threshold`, `success_threshold`, and for HTTP `scheme` and `method`.
  Fly accepts the machine without them, and then starts nothing. A machine that got such a
  config can stay stuck after the config is fixed; destroy it and run `monitor/deploy.sh`
  again. The volume keeps the data.
- **A container ignores a setting in its `env`.** When the image sets the same variable
  itself, the image's value wins and Fly gives no warning. The Grafana image sets
  `GF_PATHS_DATA`, so the `grafana` container sets it in its `cmd` (`GF_PATHS_DATA=/data/grafana
  exec /run.sh`) instead. Check a running process's variables with
  `tr '\0' '\n' < /proc/<pid>/environ` in `fly machine exec`.
- **The relay logs `heartbeat failed: HTTP Error 403`.** Cloudflare refused the request
  itself (error 1010, a banned `User-Agent`); the Worker answers 401 for a wrong token.
- **"Monitor silent" arrives although the monitor works.** Check how often Alertmanager sends
  the Watchdog (`alertmanager_notifications_total{integration="webhook"}`): about once a
  minute. Its route needs `group_interval` and `repeat_interval` below 1m, or a repeat waits
  for the next tick and pings come every 2 minutes.
- **A container gets "Connection refused" from VictoriaMetrics or VictoriaLogs on
  `localhost`.** They listen on IPv4 only unless they have `-enableTCP6`, and `localhost` can
  be `::1`.
