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
| `victoriametrics` | Metrics, kept 1 year, on port 8428 | `/data/vm` |
| `victorialogs` | Logs, kept 30 days, on port 9428 | `/data/vl` |
| `vmalert` | Evaluates the alert rules in `monitor/vmalert/rules.yml` each 30 s | in VictoriaMetrics |
| `alertmanager` | Groups alerts and sends them to the relay | `/data/alertmanager` |
| `hark` | Rewrites each alert for hark and sends it to your phone (`monitor/hark/relay.py`) | |
| `grafana` | Dashboards, from `monitor/grafana/`, on 127.0.0.1:3000 only | `/data/grafana` |

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

## Dashboards

Grafana loads its data sources and dashboards from `monitor/grafana/` at start:

- **Node Exporter Full** (grafana.com 1860): CPU, memory, disks, network, temperatures and
  systemd units. Choose a box with "Instance".
- **SMARTctl Exporter Dashboard** (22604): drive health.
- Logs: Explore, with the data source VictoriaLogs. For example `host:lab-2 _SYSTEMD_UNIT:sshd.service`.

Both dashboards select by the labels `job` and `instance`, which Vector adds on the lab boxes
(`modules/nixos/server.nix`): `instance` is the box's name, and `job` is `node`, `smartctl` or
`vector`.

Changes made in Grafana are not saved. To change a dashboard or add one, put its JSON in
`monitor/grafana/dashboards/`, add it to the `grafana` container's `files` in
`monitor/machine.json`, and deploy. A dashboard downloaded from grafana.com may name its data
source `${DS_PROMETHEUS}`; replace that with `victoriametrics`, and delete its `__inputs`.

## Alerts

vmalert evaluates `monitor/vmalert/rules.yml` and sends what fires to Alertmanager
(`monitor/alertmanager/alertmanager.yml`), which sends it to hark through a relay
(`monitor/hark/relay.py`). The relay rewrites Alertmanager's JSON into hark's: the summary is
the alert and the box, the body has a line for each alert, and a tap opens Grafana's alerts.
hark gets a second message when an alert resolves, and a repeat each 12 hours while it fires.
The hark webhook URL is the Fly secret `HARK_WEBHOOK_URL`; only the `hark` container gets it.

Every alert goes to your phone, so there are few: each needs a person, soon, and fires rarely.
Trends that can wait, such as drive wear, temperatures, swap and Vector's queues, are on the
dashboards. There is no Discord: a channel that nobody reads is not an alert
([Decisions](decisions.md#monitoring)).

| Alert | When |
| --- | --- |
| `BoxSilent` | A lab box sent no metrics for 3 minutes. Its other alerts are held back. |
| `DriveFailing`, `DriveCriticalWarning` | A drive fails its SMART check, or reports an NVMe critical warning |
| `DiskAlmostFull` | A filesystem is over 90 % full for 10 minutes |
| `CoreServiceFailed` | yonderd, tailscaled, vector, sshd, nix-daemon, systemd-resolved, dhcpcd, opnix-secrets or the SMART exporter failed for 5 minutes |
| `LowMemory` | Under 10 % of memory free for 15 minutes |
| `Watchdog` | Always. It will go to a heartbeat outside the monitor, which alerts when it stops. |

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
- **A container gets "Connection refused" from VictoriaMetrics or VictoriaLogs on
  `localhost`.** They listen on IPv4 only unless they have `-enableTCP6`, and `localhost` can
  be `::1`.
