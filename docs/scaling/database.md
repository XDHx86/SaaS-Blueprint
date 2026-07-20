# Scaling — Database Considerations

PostgreSQL scales **vertically** until it demonstrably cannot, then jumps to read replicas and (eventually) sharding. Rushing to scale-out before the vertical ceiling is exhausted is one of the more common expensive mistakes. See [ADR-0002](../adr/0002-use-postgresql.md).

## The vertical-first principle

A single Postgres handles far more than people assume on a box with enough RAM (to cache the active working set) and fast disks (so WAL and tables are not I/O-bound). Before scaling *out*, scale *up*:

| Lever | What it does | Trigger to bump |
| --- | --- | --- |
| RAM | enlarges `shared_buffers` and the OS page cache → more of the working set in memory | `cache hit ratio` dropping below ~99% |
| CPU | faster query planning + more parallel workers | sustained CPU saturation, `pg_stat_activity` backing up |
| Disk IOPS / throughput | faster WAL + table scans | `pg_stat_user_tables.seq_scan` latency climbing on hot tables |

The Postgres exporter (already in this stack) feeds Prometheus the metrics that tell you when you've exhausted each lever. The thinking precedes the movement.

## Connection pooling (because stateless replicas multiply connections)

Each backend replica opens a `pg.Pool` with `max: 10` in this reference, so the total connection count is `BACKEND_REPLICAS × 10`. Postgres handles a few hundred idle connections, but each one carries overhead (RAM, file descriptors, planning state). The horizontal scaling of the backend therefore **costs the database** — and the fix is a pooler.

| Approach | Where | Notes |
| --- | --- | --- |
| Bounded pool per replica (`pg.Pool max`) | the backend | what this reference uses — simplest, sufficient to a few replicas |
| External pooler (PgBouncer, pgcat) | a sidecar / separate service | transaction-mode pooling collapses hundreds of client connections to a few DB connections; the correct step at scale |

The trigger to add PgBouncer is "Postgres reports more connections than it can comfortably keep busy" or "replica count × pool_max > 100s." Not before.

## Read replicas

When **read** volume is the bottleneck (not writes), add read replicas:

- Postgres streaming or logical replication to 1+ replicas.
- The backend routes **reads** to a replica and **writes** to the primary — a split that requires the application to know which it issued.
- Replicas lag (milliseconds to seconds), so **read-your-writes** expectations must be managed: route the read that must reflect a just-issued write to the primary.

This is a real architectural step, not a flag. It belongs at the rung above Compose (multi-node), because a replica on the same host as the primary does not give you the availability properties you wanted — it shares the host's failure domain.

## Writes are the hard axis

Vertical scaling buys you writes up to the **single-primary ceiling**. Beyond that, sharding / partitioning is the only real lever, and it is genuinely expensive:

- **Declarative partitioning** (Postgres native) for large append-mostly tables (events, logs) — cheap, contiguous ranges per partition, time-based.
- **Application-level sharding** (route by key) for write-saturated hot tables — real complexity; correctness and operational burden.
- distribute this across nodes → you have reinvented Citus, and the right answer is probably to adopt Citus (or a distributed store) rather than hand-roll it.

The honest scaling move, when you get here, is "stop running this in Compose and run it on a platform with real replication and a sharded datastore." Each ADR's Consequences names that trigger.

## What this reference gives you in the meantime

The exporter scrapes Postgres; the dashboard shows request rate and host pressure; `HighHostMemory` and `DiskAlmostFull` alert. None of those is "you need read replicas" — but `cache hit ratio`, `connection count`, and `replication lag` are the metrics you'd add to that panel the moment you do.

## See also

- [stateless-services.md](stateless-services.md) — where the connection multiplications come from
- [caching.md](caching.md) — postponing the vertical ceiling
- [ADR-0002](../adr/0002-use-postgresql.md) — why Postgres
