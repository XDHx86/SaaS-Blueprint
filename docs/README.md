# Documentation

Structured by concern, not by component. Start with [getting-started.md](getting-started.md) to run the stack, then read the section that matches what you are doing.

The philosophy behind *why* this is organized this way lives in [SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md); the *decisions* live in [adr/](adr/).

## Reading order by intent

| You want to... | Read |
| --- | --- |
| Run it in 5 minutes | [getting-started.md](getting-started.md) |
| Understand the system | [architecture/](architecture/) → [adr/](adr/) |
| Operate it | [operations/](operations/) |
| Secure it | [security/](security/) |
| Grow it | [scaling/](scaling/) |
| Change it | [development/](development/) |
| Understand a past call | [adr/](adr/) |

## Sections

### [architecture/](architecture/) — what the system *is*
- [overview.md](architecture/overview.md) — system overview (mirrors the diagrams)
- [networking.md](architecture/networking.md) — networks, host vs internal ports, egress
- [service-communication.md](architecture/service-communication.md) — how FE ↔ BE ↔ DB ↔ cache talk; the contract
- [environment-variables.md](architecture/environment-variables.md) — full env reference
- [container-strategy.md](architecture/container-strategy.md) — image design, layering, hardening

### [operations/](operations/) — how we *run* it
- [deployment.md](operations/deployment.md) — bring-up, rollout, drain, rollback
- [backup-restore.md](operations/backup-restore.md) — pg_dump approach, schedule, restore drill
- [logging.md](operations/logging.md) — structured logs, drivers, aggregation notes
- [monitoring.md](operations/monitoring.md) — metrics, dashboards, SLO thinking
- [health-checks.md](operations/health-checks.md) — liveness vs readiness, composite health

### [security/](security/) — how we *protect* it
- [overview.md](security/overview.md) — threat model summary
- [secrets-management.md](security/secrets-management.md) — `.env` → SOPS/Vault, rotation
- [tls.md](security/tls.md) — Cloudflare → Caddy automatic TLS
- [network-security.md](security/network-security.md) — least-privilege ports, closed DB
- [container-security.md](security/container-security.md) — non-root, read-only, cap drop, distroless notes

### [scaling/](scaling/) — how it *grows*
- [overview.md](scaling/overview.md) — scaling model and the limits of Compose
- [stateless-services.md](scaling/stateless-services.md) — why the backend scales horizontally
- [database.md](scaling/database.md) — vertical-first, read replicas, connection pooling
- [caching.md](scaling/caching.md) — cache-aside with Redis, invalidation

### [development/](development/) — how we *change* it
- [local-development.md](development/local-development.md) — override file, source-mount dev loop, debug
- [branch-strategy.md](development/branch-strategy.md) — trunk-based, short-lived branches
- [release-strategy.md](development/release-strategy.md) — semantic versioning, tags, CHANGELOG

### [adr/](adr/) — why we *chose* it
- [README.md](adr/README.md) — ADR index + how to write one
- 0001 → 0008 — one ADR per significant decision

## Conventions used across docs

- Service names, internal ports, env vars, and volumes are the **locked conventions** from the [README](../README.md) — see [architecture/environment-variables.md](architecture/environment-variables.md) for the canonical table.
- Every doc ends with a **See also** footer linking the sibling and parent docs it depends on.
- Diagrams are linked to their `.mmd` source in [`architecture/diagrams/`](../architecture/diagrams/) — diagrams-as-code, never screenshots.
