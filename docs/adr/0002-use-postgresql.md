# ADR-0002 — Use PostgreSQL as the primary datastore

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

The system needs a durable, transactional store for application state. The decision drives: the consistency model, the operational complexity (backup/restore, replication), the query surface, and the scaling posture for years.

Forces:

- *Correctness* — the durable store must hold the strongest guarantees we reasonably can; data loss here is the worst failure.
- *Operational maturity* — the store must have credible, well-trodden backup/restore and replication stories.
- *Ecosystem* — tooling (exporters, ORMs, pooling) must be broad and current.
- *Scaling honesty* — the choice must not imply the store scales out effortlessly; write-scaling is the hard axis.

## Decision

Use **PostgreSQL** (v16) as the primary datastore. One primary; reads route to it; writes pass through it.

## Consequences

**Easier.**

- Strong **ACID** guarantees by default; correctness is the cheap path.
- A rich ecosystem: `pg` driver, `postgres-exporter`, `pg_dump`/PITR tooling, ORMs on every platform.
- Mature **streaming/logical replication** when read replicas are later required (vertical-first, see [../scaling/database.md](../scaling/database.md)).
- Extensions (e.g. `pg_trgm`, PostGIS, `pg_stat_statements`) cover most "we need X" without re-platforming.

**Harder.**

- **Write-scaling is hard.** A single primary is the write bottleneck beyond the vertical ceiling; scaling writes requires partitioning or distribute (Citus, sharding) — genuine complexity.
- Operational depth: `postgresql.conf` tuning, vacuum management, and connection cost are real skills an operator must invest in at scale.
- A connection is not free — each costs RAM and file descriptors, and stateless replica spread multiplies them (see [../scaling/database.md](../scaling/database.md) on pooling).

**Scope limit — when to revisit.** When the working set exceeds available RAM on a single host, write QPS exceeds the single-primary ceiling, or read load outgrows primary + read replicas, Postgres single-primary has reached its limit. The path is **read replicas first** (still Postgres), then **sharding / distribute** (Citus or a distributed store). The trigger to leave Postgres entirely — "we genuinely cannot shard by app logic and need auto-sharding" — is rare; more often the application stays on Postgres and the scaling problem moves to *connection pooling and read splitting*, which this repo names at the rung above.

## Alternatives considered

- **MySQL** — excellent, broadly comparable. Rejected on ecosystem grounds: Postgres's extension model and richer index/constraint surface made the trade-off land here for a general SaaS reference. Either would be defensible; the matrix documents the call.
- **MongoDB / a document store** — appropriate for document-shaped, schema-tolerant data; rejected as the *primary* durable store because the ACID + relational default matches most SaaS state. Could sit **alongside** Postgres for a specific bounded use case.

## See also

- [../operations/backup-restore.md](../operations/backup-restore.md) — the operational consequence
- [../scaling/database.md](../scaling/database.md) — the scaling posture
- [0008](0008-backup-strategy.md) — the backup mechanism
