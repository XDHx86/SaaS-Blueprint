# Scaling — Caching Strategy

The cache is a **trade**, not a free win: it buys you read-headroom on the database at the cost of consistency and invalidation discipline. This reference uses **cache-aside** with Redis — the simplest model that still teaches the responsibilities. See [ADR-0003](../adr/0003-use-redis.md).

## Cache-aside

```mermaid
flowchart LR
    BE["Backend"] -->|"1. GET key"| RD[("Redis")]
    RD -.hit.-> BE
    RD -.miss.-> BE
    BE -.2. read DB on miss.-> PG[("PostgreSQL")]
    PG --> BE
    BE -->|"3. WRITE key (with TTL)"| RD
```

The pattern in the backend:

1. **Read path:** check Redis. On hit, return. On miss, read Postgres, write the value to Redis with a TTL, return.
2. **Write path:** write to Postgres. **Invalidate** the cache key (delete, or write-through).
3. **TTL is the safety net** for the case where an invalidation is missed — stale data expires on its own, recovering correctness eventually.

### Why cache-aside over the alternatives

| Pattern | Trade |
| --- | --- |
| **Cache-aside** (this repo) | simplest; the cache and the DB are *unrelated stores*; on cache failure you fall through to the DB. Chosen. |
| Read-through / write-through | hides the cache behind a library; elegant, but couples cache and DB lifecycles, and obscures the fallback |
| Write-behind | writes to cache first, async to DB — highest throughput, **accepts data loss on failure**; not worth it until you've measured the write ceiling |

Cache-aside keeps the **fallback explicit**: if Redis is down, the read hits Postgres and the request still succeeds. That is why `RedisDown` is a `warning`, not a `critical` — the system degrades, it does not fail.

## The cache is not a source of truth

This is the one rule that, broken, causes the hardest bugs:

- **Postgres is the source of truth.** The cache is a derived view.
- **Never write to the cache you are not willing to lose.** It is volatile by definition; anything in Redis that you cannot reconstruct from Postgres is a single-host failure away from data loss.
- **Sessions: acceptable to put in Redis.** Recreating a session costs the user a login; that is recoverable. **Orders, accounts, balances: never Redis-only.**

## Invalidation discipline

| Event | Invalidate |
| --- | --- |
| Write to a row | delete the key derived from that row |
| Batch write | delete the set of affected keys (a *channel* publish, or a key-prefix scan) |
| TTL default | every key gets one — the safety net for missed invalidations |
| Schema / bulk reload | flush the affected namespace (deliberate, rare) |

Two anti-patterns to name so they are not reinvented:

- **Cache stampede** (N replicas all miss the same cold key and stampede Postgres). At scale, guard with a short per-key lock or a *stale-while-revalidate*; not done here, named as the upgrade.
- **Thundering invalidation** (a hot key is invalidated on every write so you effectively never cache it). Means the key is too hot to cache; accept it, or denormalize the read path.

## What belongs in Redis (and what doesn't)

| Good fit | Bad fit |
| --- | --- |
| Session state | durable records (they belong in Postgres) |
| Computed/expensive reads with TTL | single-row reads that are already cheap |
| Rate-limit counters | anything you can't afford to lose |
| Feature flags toggled often | slow-changing config (it's in env / git) |

## The honest trade

Caching **postpones** the database's vertical ceiling (see [database.md](database.md)) — a well-tuned cache can turn a 1k-QPS read load into a 100-QPS read load on Postgres. But it adds:

- a dependency you must monitor (`RedisDown`),
- a consistency surface you must reason about (stale reads),
- an invalidation discipline you must maintain (and review).

When the cache stops buying room — when cache hit ratio plateaus despite traffic — you have hit the cache's ceiling, and the answer is to revisit the DB scaling, not to cache harder.

## See also

- [database.md](database.md) — what the cache postpones
- [stateless-services.md](stateless-services.md) — why sessions live in Redis, not the process
- [../architecture/service-communication.md](../architecture/service-communication.md) — cache as best-effort, not a dependency
- [ADR-0003](../adr/0003-use-redis.md) — why Redis
