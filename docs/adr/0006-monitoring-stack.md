# ADR-0006 — Use Prometheus + Grafana for observability

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

The system needs to be **legible**: aggregate metrics with rules, dashboards that reflect the current system, and an alert routing layer that owns grouping, inhibition, and receiver choice. The choice is between an OSS, self-hostable stack and a SaaS aggregator.

Forces:

- *Diffability of observability* — dashboards and rules should live in the repository, not behind a vendor login.
- *Portability* — the model should transfer to most organizations a reader is likely to join.
- *Pull vs push* — whether services ship to a collector or a collector pulls from services.
- *Cost & lock-in* — OSS keeps the data where the system runs; SaaS adds a bill and an integration whose removal is costly.

## Decision

Use **Prometheus** (scrape → record → alert), **Grafana** (auto-provisioned dashboards), and **Alertmanager** (routing, grouping, inhibition) — all OSS, all configured-as-code in [`monitoring/`](../../monitoring/). Prometheus pulls `/metrics` from each target on an interval; recording rules pre-compute SLO indicators; alerting rules threshold them; Alertmanager routes by severity and inhibits lower severities when a higher one fires.

## Consequences

**Easier.**

- **Dashboards and rules live in git** — versioned, reviewed, never hand-imported. A panel that drifts from the system is a bug, not a feature.
- The **pull model** keeps the dependency graph one-directional — targets do not depend on Prometheus; a scrape failure doesn't affect serving.
- Portable: most readers will have met this exact stack; the mental model transfers.
- Recording rules are one place to change an indicator every consumer reads — cheap to query repeatedly.

**Harder.**

- Prometheus HA is **not** its strength — in this single-host reference it's tolerable; HA Prometheus requires federation or thanos/vmagent, an explicit step above.
- Storage scale: TSDB *does* grow; retention (`PROM_RETENTION`) and disk pressure are real operational concerns (see the `DiskAlmostFull` alert).
- Operational depth — alert tuning, rule design, and dashboard hygiene are skills; the reference embodies them but does not replace them.
- Tracing is **out of scope** — this is metrics-only; tracing is the obvious, named next step (OTel collector + a backend).

**Scope limit — when to revisit.** When Prometheus must run HA (multi-host), when the retention window is too long for a single TSDB (introduce **Thanos** or **Mimir** for long-term storage), or when tracing is required (add an OTel collector + a trace backend). When the org prefers no operational surface at all, a **SaaS** (Datadog, Grafana Cloud) replaces the role; the dashboards-in-git discipline and the alert-model thinking transfer regardless.

## Alternatives considered

- **Datadog / a SaaS aggregator** — removes operational surface and (often) offers better out-of-the-box correlation; rejected because the dashboards and rules then live behind a vendor login, and because a reference should run from a clone without a paid account. The model transfers to either deployment style.
- **VictoriaMetrics + vmalert** — a Prometheus-compatible, more-efficient-at-scale alternative; a fine choice and largely a drop-in. Rejected here on "familiar" grounds — Prometheus is the default the broadest audience expects.

## See also

- [`monitoring/README.md`](../../monitoring/README.md) — the implementation
- [../operations/monitoring.md](../operations/monitoring.md) — the runbook
- [`architecture/diagrams/observability-flow.mmd`](../../architecture/diagrams/observability-flow.mmd)
