# Architecture Decision Records

An **ADR** captures the context, decision, and consequences of a single architectural choice. It explains *why this, not that* — the trade-off, not the recommendation. A decision without a recorded rationale is a decision someone will quietly relitigate later.

ADRs are **immutable**: a superseded decision is not edited away; it is marked *Superseded* by a new ADR. The history is the artifact.

## Index

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-use-docker-compose.md) | Use Docker Compose for orchestration | Accepted |
| [0002](0002-use-postgresql.md) | Use PostgreSQL as the primary datastore | Accepted |
| [0003](0003-use-redis.md) | Use Redis as the cache / session store | Accepted |
| [0004](0004-reverse-proxy-selection.md) | Use Caddy as the reverse proxy | Accepted |
| [0005](0005-environment-configuration.md) | Use `.env` + overlays for configuration | Accepted |
| [0006](0006-monitoring-stack.md) | Use Prometheus + Grafana for observability | Accepted |
| [0007](0007-cicd-strategy.md) | Use GitHub Actions for CI/CD | Accepted |
| [0008](0008-backup-strategy.md) | Use `pg_dump` for backups | Accepted |

## Format

Each ADR follows the same structure (a trimmed [MADR](https://adr.github.io/madr/) shape):

- **Status** — Accepted / Superseded / Deprecated
- **Context** — the problem, the forces, the alternatives considered
- **Decision** — the choice, stated plainly
- **Consequences** — what becomes easier, what becomes harder, the explicit **scope limit** (when the decision should be revisited)
- **Alternatives considered** — the options rejected, and why

## How to add one

1. Copy the next number, e.g. `0009-<short-slug>.md`.
2. Fill the sections. Be concrete: name the trigger that would push you off the decision.
3. Add a row to this index with the status.
4. If your ADR supersedes another, mark the old one *Superseded by 00NN* and link to the new one.

## See also

- The [README decision matrix](../../README.md#architecture-decisions) — one-line summary of each
- [`SYSTEM_DESIGN.md`](../../SYSTEM_DESIGN.md) — the philosophy behind the choices
- [architecture/](../architecture/) — what the choices produced
