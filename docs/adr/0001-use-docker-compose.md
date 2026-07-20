# ADR-0001 — Use Docker Compose for orchestration

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

The repository models a single-host SaaS deployment and must be **readable in 90 seconds**, **runnable with one command**, and **faithful to the operational concepts** a real deployment uses (services, volumes, networks, health, observability). The orchestration choice determines how much incidental complexity the reader must absorb before they understand the system.

Forces:

- *Cognitive load* — the scaffolding must not dwarf the system it scaffolds.
- *Portability of the mental model* — concepts here should map upward to larger systems (Kubernetes), so the reasoning transfers.
- *Operational fidelity* — health gates, rolling updates, immutability, and overlays should all be expressible.
- *Honesty about scale* — the choice must name what it *cannot* do, not imply it can run a fleet.

## Decision

Use **Docker Compose** as the orchestration layer, with a **base file + overlays** (local override, production), and the `deploy.replicas` directive for horizontal scaling (honored under `--compatibility`).

## Consequences

**Easier.**

- One declarative file is the entire system; a reader holds it in one screen.
- `make up` brings the full stack up; a recruiter or reviewer can *touch* the architecture, not just read about it.
- Concepts (service, network, volume, health, overlay) map 1:1 to Kubernetes primitives, so the model transfers.
- Low operational overhead — no control plane to back up, upgrade, or secure.

**Harder.**

- No orchestration: no automatic rescheduling, bin-packing, or self-healing across hosts.
- No autoscaling: replicas are a literal count, not driven by metrics.
- Single host — no real clustering or HA; a host failure takes down the service.
- No scheduler-level rolling updates or canaries — deployments are `make restart` / `make prod-up`, all replicas at once.

**Scope limit — when to revisit.** When the system requires more than one host, automatic scaling by metrics, self-healing across node failures, or canary rollouts, Compose has been outgrown. The trigger to move is a concrete requirement along one of those axes, not "we might need it." The rung above is **Kubernetes** (or an equivalent scheduler); the growth ladder is documented in the [README](../../README.md#future-evolution). Nothing in this repo's structure needs to change to do that — only the tool that interprets the declaration.

## Alternatives considered

- **Kubernetes** — the correct answer at real scale; rejected here because it obscures the architecture behind a control plane the reader would have to learn before reading the system. The reference does not need a cluster; it needs to *demonstrate a cluster's concepts*.
- **Nomad / a simpler scheduler** — a middle rung, smarter than Compose, simpler than K8s. Rejected because the audience expects Compose/K8s and the cognitive overhead of a third tool is not worth the single-host reference.

## See also

- [../scaling/overview.md](../scaling/overview.md) — the scaling model and the ladder above Compose
- [../architecture/networking.md](../architecture/networking.md) — the single-network, single-host topology
- [README § Trade-offs](../../README.md#trade-offs) — the pros/cons in full
