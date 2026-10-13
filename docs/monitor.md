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
| `tailscale` | Joins the tailnet as `monitor`, with the tag `tag:monitor` | `/data/tailscale` |
| `victoriametrics` | Metrics, kept 1 year, on port 8428 | `/data/vm` |
| `victorialogs` | Logs, kept 30 days, on port 9428 | `/data/vl` |
| `grafana` | Dashboards, on port 3000 | `/data/grafana` |

The machine has no public IP and no Fly services, so nothing on the internet can connect to
it. The lab boxes and your devices reach it over the tailnet: `http://monitor:3000` for
Grafana. The tailnet policy (`tailscale-acls`) lets lab boxes reach only ports 8428 and 9428.

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

3. Create the volume and the machine:

   ```sh
   monitor/deploy.sh
   ```

4. Check that `monitor` is on the tailnet, and that the app has no IPs:

   ```sh
   tailscale status | grep monitor
   monitor/deploy.sh status
   ```

5. Open `http://monitor:3000`, log in as `admin` with the password `admin`, and set a new
   password. Grafana keeps it on the volume.

## Change it

Edit `monitor/machine.json` or the files next to it, then run `monitor/deploy.sh` again. When
the machine exists, it runs `fly machine update`, which keeps the volume.

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
- **A container gets "Connection refused" from VictoriaMetrics or VictoriaLogs on
  `localhost`.** They listen on IPv4 only unless they have `-enableTCP6`, and `localhost` can
  be `::1`.
