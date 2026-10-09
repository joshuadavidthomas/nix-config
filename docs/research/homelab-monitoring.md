# Homelab monitoring

Decided on 2026-10-09. Not built yet. The tasks are in the [roadmap](../roadmap.md#monitoring).

## Decision

- Vector on each lab box sends metrics and logs to one Fly machine.
- The Fly machine runs VictoriaMetrics, VictoriaLogs, vmalert and Grafana.
- A heartbeat Worker on Cloudflare alerts when the lab boxes or the Fly machine stop sending.
- Later, Vector also sends the same data to a Cloudflare Basin lake. The Victoria stack is the
  reference to check the lake against.

## Why

- The Victoria stack takes about one evening to set up, with no custom code: PromQL, the stock
  node_exporter dashboards and vmalert.
- Fly and Cloudflare are outside the homelab. A homelab outage does not stop the monitor.
- VictoriaMetrics has an MCP server. An agent (pi, a Discord bot) can query metrics without the
  lake.
- Vector sinks are interchangeable. Basin is one more sink, not a migration.

## Design

On each lab box:

- Vector scrapes the exporters, or uses its own `host_metrics` source.
- Vector keeps only the useful series.
- Vector buffers to disk. An ISP outage leaves no gap.
- The configuration goes in `services.vector.settings` in `modules/server.nix`.

On Fly, one machine with one volume:

- VictoriaMetrics receives `prometheus_remote_write`.
- VictoriaLogs receives logs.
- vmalert evaluates the alert rules.
- Grafana shows the stock dashboards.

Panels: CPU, memory, disk use and I/O, network, temperatures, containers, drive health, UPS,
and journald logs.

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
- [ ] Grafana access: Cloudflare Access in front of Fly, or Fly private networking over
      Tailscale?
- [ ] How does the Pipelines sink partition by default? Is day and host possible before custom
      partitioning?
- [ ] Vector straight to Pipelines, or an ingest Worker in front for per-host tokens and
      validation?
- [ ] Does the "Analytics SQL binding" in Wrangler 4.145 query Basin SQL or Analytics Engine? If
      Basin SQL, Workers can query without a token.
- [ ] Which 50 to 100 series per host to keep?
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
