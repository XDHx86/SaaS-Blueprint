# Operations — Logging

Logs are structured, line-delimited, written to the container's stdout/stderr, and collected by the Docker logging driver. That is the whole model — deliberately simple for a single-host reference, with a documented upgrade path to an aggregation layer.

## The contract

- **stdout/stderr only.** Services log to stdout/stderr, never to files inside the container. The container's filesystem is read-only in prod; a log file would be a write that does not happen.
- **Structured (JSON).** The backend logs via pino (Fastify's logger), one JSON object per line: `{"level":30,"time":...,"msg":"backend listening",...}`. nginx logs to its access/error format; Caddy emits structured access logs.
- **One process per line, one line per event.** No multi-line dump that a collector has to stitch together.

## What you actually do

```bash
make logs                       # docker compose logs -f --tail=200 (all services)
docker compose -f compose/docker-compose.yml logs -f backend    # one service
```

`make logs` tails. For a point-in-time view across the stack, `make ps` + `make health` tell you the state; logs tell you the *events* that produced it.

## The Docker logging driver

The default driver (`json-file`) is used here without rotation tuning because the reference is short-lived and single-host. For anything long-running, **rotate**:

```yaml
# add to a service in your own overlay, or set globally via daemon.json
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Not setting rotation is a disk-fill risk over weeks; `DiskAlmostFull` ([`monitoring/rules/alerts.yml`](../../monitoring/rules/alerts.yml)) would catch the consequence, not the cause.

## The upgrade path

| Stage | Mechanism |
| --- | --- |
| Reference (here) | json-file driver + `make logs` |
| Small fleet | `local`/`journald` or `fluentd`/`loki` sidecar, tail to object storage |
| Multi-service / searchable | a log aggregator (Loki + Promtail, or OpenSearch) ingesting the docker driver output |

The split between **logs** (per-event) and **metrics** (aggregated) matters here — do not put a counter in the logs and grep for it; put it in `/metrics` so Prometheus records it. See [monitoring.md](monitoring.md).

## Log levels

The backend honors `LOG_LEVEL`: `debug` (dev override), `info` (default), `warn` (prod). A prod stack should not run at `debug` — it is noisy and rarely the signal you need when something is wrong. Readiness failures are logged at `warn`; they are a condition to track, not a reason to panic.

## See also

- [monitoring.md](monitoring.md) — metrics, the aggregate view
- [security/secrets-management.md](../security/secrets-management.md) — don't log secrets
- [`monitoring/rules/alerts.yml`](../../monitoring/rules/alerts.yml) — `DiskAlmostFull` catches the consequence of unrotated logs
