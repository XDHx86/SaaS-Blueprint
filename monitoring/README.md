# Monitoring

The observability stack: **Prometheus** (scrape, record, alert), **Grafana** (dashboards, auto-provisioned), and **Alertmanager** (routing, grouping, inhibition). Three exporters feed Prometheus: `postgres-exporter`, `redis-exporter`, and `node-exporter`.

## Layout

```
monitoring/
├── prometheus.yml                    # scrape configs + rule/alert references
├── rules/alerts.yml                  # recording + alerting rules (SLOs)
├── alertmanager/alertmanager.yml     # routing by severity, inhibition, receivers
└── grafana/
    ├── provisioning/
    │   ├── datasources.yml            # Prometheus provisioned as default DS (uid: prometheus)
    │   └── dashboards.yml             # dashboard provider pointing at dashboards/
    └── dashboards/overview.json        # reference dashboard
```

## Scrape targets

All targets live on `infra-lab-net` and match the service names in [compose/docker-compose.yml](../compose/docker-compose.yml):

| Job | Target | Exposes |
| --- | --- | --- |
| `backend` | `backend:8080/metrics` | request count, uptime, build info |
| `proxy` | `proxy:2019/metrics` | Caddy admin-API metrics |
| `postgres-exporter` | `postgres-exporter:9187` | DB internals |
| `redis-exporter` | `redis-exporter:9121` | cache internals |
| `node-exporter` | `node-exporter:9100` | host CPU/mem/disk |
| `prometheus` | `localhost:9090` | self |

## Rule model

Two rule groups in `rules/alerts.yml`:

- **Recording** — pre-compute SLO indicators the dashboard and alerts both read (e.g. `job:backend_requests:rate5m`, `host:memory_used:ratio`). Cheap to query repeatedly; one place to change the formula.
- **Alerting** — thresholds on those indicators, with `for` durations to ride out flapping. A `Watchdog` sentinel is always firing so a *quiet pipeline* is never mistaken for a *working* pipeline.

## Alert routing

`alertmanager/alertmanager.yml` routes by `severity`:

- `critical` → `web-ops` (repeats hourly, short `group_wait`)
- `warning` → `oncall`
- `info` → `dead-letter` (the `Watchdog` sink)

Grouping by `[alertname, group]` keeps one ticket per outage. An **inhibit rule** suppresses `warning` alerts in the same `group` while a `critical` is firing — so a proxy outage doesn't fan out into a ticket per dependent exporter. All receivers are **placeholder webhooks**; configure real Slack/email before relying on this (see [docs/operations/monitoring.md](../docs/operations/monitoring.md)).

## Dashboards are versioned

Grafana provisioning loads dashboards from the bind-mounted `grafana/dashboards/` directory — dashboards live in this repository, are reviewed like code, and are **never hand-imported**. That is the point: a panel that drifts from the system it graphs is a silent lie.

## See also

- [docs/operations/monitoring.md](../docs/operations/monitoring.md)
- [architecture/diagrams/observability-flow.mmd](../architecture/diagrams/observability-flow.mmd)
- [ADR-0006](../docs/adr/0006-monitoring-stack.md)
