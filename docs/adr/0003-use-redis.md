# ADR-0003 — Use Redis as the cache / session store

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

The stateless backend needs a place for **sessions** and **hot reads** that does not sit in Postgres's hot path. The choice trades latency and load for a consistency and durability surface an operator then owns.

Forces:

- *Latency* — a cache hit at sub-millisecond latency removes a DB read from the hot path.
- *Richness* — sessions and rate-limit counters benefit from data structures a bare key/value store does not offer.
- *Recoverability* — the cache must not be the source of truth; losing it must not lose durable data.
- *Operational simplicity* — one cache process, monitored, with a clear incapacity behavior.

## Decision

Use **Redis** (v7) with **appendonly persistence** for cache and session state, accessed via **cache-aside** on the read path and explicit invalidation on the write path. The cache is **best-effort**: if Redis is unavailable, the backend falls through to Postgres and the request still succeeds (see [../scaling/caching.md](../scaling/caching.md)).

`requirepass` is set by `make bootstrap` (see [../security/secrets-management.md](../security/secrets-management.md)); the cache is **not** published to the host and is reachable only inside `infra-lab-net`.

## Consequences

**Easier.**

- Persistent (AOF) yet cheap: survives a restart, never claims to be the source of truth.
- Rich data structures (strings, hashes, sets, sorted sets) — sessions, rate-limit tokens, leaderboards, lock primitives.
- Pub/sub enables cache invalidation broadcasts when multi-replica invalidation matters.
- Latency in the sub-millisecond regime; takes read load off Postgres and **postpones** the database's vertical ceiling.

**Harder.**

- A **consistency surface** you must reason about: cached reads can be stale until invalidated or TTL-expired (see [../scaling/caching.md](../scaling/caching.md) for the invalidation discipline).
- An **additional dependency** to monitor — `RedisDown` (warning), `redis-exporter` memory.
- In-memory sizing: the working set must fit in RAM; eviction policy matters at the limit.
- Single-node in this reference — no clustering, no HA; the cache is down if the host is.

**Scope limit — when to revisit.** When the working set exceeds a single host's RAM; when cache HA is required (Redis Cluster / a managed equivalent); or when read throughput exceeds what one Redis node serves — switch to **Redis Cluster** or a managed cache. The trigger is a measurement: cache hit ratio plateauing despite the working set growing, or measured single-node Redis saturation. Postgres remains the source of truth either way; the cache layer changes independently.

## Alternatives considered

- **Memcached** — exemplary at pure key/value caching; rejected because it offers no persistence, no rich data structures, and no pub/sub — three things this reference deliberately demonstrates (sessions, rate-limit counters, invalidation).
- **DragonflyDB** — a Redis-compatible, multi-threaded alternative with better throughput-per-node; rejected for ecosystem maturity (tooling, clients, operator familiarity) at the time of writing. A viable future swap given API compatibility.

## See also

- [../scaling/caching.md](../scaling/caching.md) — the full caching strategy
- [../architecture/service-communication.md](../architecture/service-communication.md) — cache as best-effort dependency
- [../security/secrets-management.md](../security/secrets-management.md) — `requirepass`
