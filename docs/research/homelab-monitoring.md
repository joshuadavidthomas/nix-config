# Homelab monitoring

Decided on 2026-10-09. The exporters and Vector are configured on the lab boxes, but send nothing
yet.
The tasks are in the [roadmap](../roadmap.md#monitoring).

## Decision

- Vector on each lab box sends metrics and logs to one Fly machine, over Tailscale.
- The Fly machine runs VictoriaMetrics, VictoriaLogs, vmalert, Alertmanager and Grafana.
- Alerts go to Discord, and to [hark](https://hark.ryan.ceo) on the phone.
- A heartbeat Worker on Cloudflare alerts when the Fly machine stops sending.
- Later, Vector also sends the same data to a Cloudflare Basin lake. The Victoria stack is the
  reference to check the lake against.

## Why

- The Victoria stack takes about one evening to set up, with no custom code: PromQL, the stock
  node_exporter dashboards and vmalert.
- Fly and Cloudflare are outside the homelab. A homelab outage does not stop the monitor.
- The Fly machine joins the tailnet, like a lab box. VictoriaMetrics and VictoriaLogs have no
  per-client auth, and the lab is a trusted network behind Tailscale
  ([Decisions](../decisions.md#monitoring)). So there is no public endpoint, and no token on
  the lab boxes.
- VictoriaMetrics has an MCP server. An agent (pi, a Discord bot) can query metrics without the
  lake.
- Vector sinks are interchangeable. Basin is one more sink, not a migration.

## Design

On each lab box, in `modules/nixos/server.nix`:

- node_exporter, with its `systemd` collector, and smartctl_exporter for drive health. Both
  listen on localhost only: `tailscale0` is a trusted interface, so on `0.0.0.0` every node on
  the tailnet could read them.
- Vector scrapes both exporters each 30 s and adds a `host` tag. Not Vector's own
  `host_metrics`: the stock dashboards need node_exporter's `node_*` names, and `host_metrics`
  has no temperatures or drive health.
- Vector reads the journal.
- Now: Vector sends nothing. Metrics go to a preview on the box, logs are dropped. See
  [Before shipping](#before-shipping).
- Later: Vector keeps only the useful series, and buffers to disk with a set `max_size`.
  VictoriaMetrics takes late samples, so an ISP outage leaves no gap.

On Fly, one machine with one volume, on the tailnet:

- VictoriaMetrics receives `prometheus_remote_write`.
- VictoriaLogs receives logs.
- vmalert evaluates the alert rules. `up == 0` and `absent()` rules catch a lab box, or the
  whole homelab, going silent.
- vmalert cannot notify by itself. It sends alerts to Alertmanager, which posts to Discord.
- Grafana shows the stock dashboards, over Tailscale.

The monitor is itself monitored: vmalert has a Watchdog rule that always fires, and
Alertmanager sends it to the heartbeat Worker. When the Watchdog stops, the Fly machine, vmalert
or Alertmanager is down, and the Worker alerts.

hark takes its own JSON (`body`, `title`, `url`) at a secret webhook URL, not Alertmanager's
webhook payload. So Alertmanager sends to a relay that translates. The heartbeat Worker can be
that relay, since it already receives Alertmanager's webhooks.

Panels: CPU, memory, disk use and I/O, network, temperatures, systemd units, drive health, and
journald logs. There is no UPS.

## Before shipping

Check what a lab box would send:

```sh
curl -s 127.0.0.1:9598/metrics | grep -v '^#' | wc -l
```

The preview also has Vector's own metrics. `vector_component_received_events_total` for
`component_id="journal"` is the journal's volume.

To start shipping, replace Vector's two sinks in `modules/nixos/server.nix`: `preview` with a
`prometheus_remote_write` sink with a disk buffer, and `logs` with a VictoriaLogs sink.

## Basin lake

One narrow `metrics` table, the same shape as Prometheus samples. A new exporter adds rows, not
columns.

| Column | Type | Example |
| --- | --- | --- |
| `ts` | timestamp | Sample time |
| `host` | string | `lab-1` |
| `metric` | string | `node_cpu_seconds_total` |
| `labels` | map<string,string> | `cpu`, `mode`, `device`, `mountpoint` |
| `value` | double | Sample value |

A `logs` table: `ts`, `host`, `unit`, `level`, `message`.

- A column for each metric breaks at each new metric. Basin SQL has map access and window
  functions for reshaping and rates.
- Counters (CPU seconds, bytes) need `lag()` for rates. Gauges (memory, temperature, free bytes)
  are read directly. The agent's schema description must say which metric is which.
- 3 hosts × 100 series × one sample each 30 s is about 860,000 rows a day.
- Partition by day and host if possible. Custom Pipelines partitioning is not released yet.

| Panel | Metric | Query |
| --- | --- | --- |
| CPU % | `node_cpu_seconds_total` | `lag()` by host, cpu, mode |
| Memory | `MemAvailable` / `MemTotal` | Gauge ratio |
| Disk full | `avail_bytes` / `size_bytes` | Gauge ratio per mountpoint |
| Disk and network I/O | Byte counters | `lag()` |
| Temperatures | `node_hwmon_temp_celsius` | Gauge |
| Up or down | Heartbeat | Durable Object, not the lake |

Limits of the lake:

- No PromQL and no stock Grafana dashboards. Rates and rollups are SQL.
- Data is minutes old. Use the lake for history, not for alerts.
- Basin SQL bills by data scanned, with a 10 MB minimum for each query. At homelab volume, the
  minimum sets the cost.
- K2 is in public beta. Stateful Pipelines processing (streaming aggregations, materialized
  views) is not released.

## Prior art: opencode

Anomaly moved the opencode data pipeline from S3 and Athena to Cloudflare Basin.

| Part | What they do | Source |
| --- | --- | --- |
| Lake | Iceberg table `inference.generation` in an R2 bucket for each stage | [infra/stats.ts](https://github.com/anomalyco/opencode/blob/dev/infra/stats.ts) |
| Cutover | S3 lake removed on 2026-10-01. Dax estimated half the cost. | [Dax on X](https://x.com/thdxr/status/2087934979166658608) |
| Queries | Own R2 SQL client: pages under the 10,000-row limit, retries on timeout, 429 and 5xx, assumes about 5 minutes of ingest lag | [r2-sql.ts](https://github.com/anomalyco/opencode/blob/dev/packages/stats/core/src/r2-sql.ts) |
| Serving | An hourly sync writes rollups to PlanetScale. The stats site reads the rollups, not the lake. | [stat-sync.ts](https://github.com/anomalyco/opencode/blob/dev/packages/stats/core/src/stat-sync.ts) |
| Alerts | A Tail Worker parses `_metric:` logs. Honeycomb triggers post to Discord. | [monitoring.ts](https://github.com/anomalyco/opencode/blob/dev/infra/monitoring.ts) |
| Agent | An opencode agent in Slack answers questions from the lake, with PNG charts | Dax's video, 2026-08-13 |

Lessons:

- Keep alerts off the lake.
- Precompute what dashboards show again and again.
- Give the agent a schema description with the quirks of the data.
- Turn on Catalog compaction for faster queries (advice from Marc Selwan, Cloudflare).

## Open questions

- [ ] Fly machine size, volume size, retention, and backups (vmbackup to R2)
- [ ] The Fly machine's Tailscale tag, and what the tailnet policy (tailscale-acls) lets it
      and `tag:lab` reach
- [ ] How does the Pipelines sink partition by default? Is day and host possible before custom
      partitioning?
- [ ] Vector straight to Pipelines, or an ingest Worker in front for per-host tokens and
      validation?
- [ ] Does the "Analytics SQL binding" in Wrangler 4.145 query Basin SQL or Analytics Engine? If
      Basin SQL, Workers can query without a token.
- [ ] Which 50 to 100 series per host to keep? Choose from the preview.
- [ ] Which journal priorities to keep? Check the volume in the preview first.
- [ ] Does hark ignore unknown fields? If so, a template could replace the relay.
- [ ] Discord through Alertmanager's `discord_configs`, or through the relay too?
- [ ] Where does the agent run: a Discord bot, pi, or opencode?

## References

Cloudflare:

- [Introducing Cloudflare Basin](https://blog.cloudflare.com/cloudflare-basin/)
- [Announcing Cloudflare K2](https://blog.cloudflare.com/cloudflare-k2-streams/) and the
  [K2 docs](https://developers.cloudflare.com/k2/)
- [Basin docs index](https://developers.cloudflare.com/basin/llms.txt)
- [R2 SQL changelog](https://developers.cloudflare.com/changelog/product/r2-sql/)
- [Pipelines and Data Catalog in Terraform](https://developers.cloudflare.com/changelog/post/2026-04-27-terraform-support/)
- [Containers concepts](https://developers.cloudflare.com/containers/concepts/): local disk is
  temporary, so no time-series database there
- [Wrangler 4.145.0](https://github.com/cloudflare/workers-sdk/releases/tag/wrangler@4.145.0)
- [Birthday Week 2026](https://cloudflare.com/birthday-week.md)

opencode:

- [anomalyco/opencode](https://github.com/anomalyco/opencode): `infra/stats.ts`,
  `packages/stats`, `packages/slack`, `infra/monitoring.ts`
- [Dax: moving the data pipeline to Cloudflare](https://x.com/thdxr/status/2087934979166658608)

Tools:

- [VictoriaMetrics MCP server](https://playbooks.com/mcp/victoriametrics/mcp-victoriametrics)
- [DuckDB Iceberg REST catalogs](https://duckdb.org/docs/current/core_extensions/iceberg/catalogs.html)
- [Evidence on R2](https://juhache.substack.com/p/0-data-distribution)
