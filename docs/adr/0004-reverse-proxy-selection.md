# ADR-0004 — Use Caddy as the reverse proxy

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

The reverse proxy terminates the origin TLS hop, routes `/api/*` to the backend and `/` to the frontend, sets a header security policy, and is the single point where these operational concerns live so the application doesn't have to. The choice trades config ergonomics and cert management against mature operator familiarity.

Forces:

- *TLS by default* — the proxy must obtain and renew the origin certificate without ceremony; certificate expiry is the classic operational failure.
- *Config readability* — the routing and policy must be readable in one screen (the 90-second standard applies here too).
- *Honest defaults* — the proxy's defaults should be safe to ship, not a footgun.
- *Operational maturity* — must have credible metrics exposure and a health story.

## Decision

Use **Caddy** as the reverse proxy. The [`Caddyfile`](../../compose/Caddyfile) declares the site block; Caddy obtains and renews an ACME certificate when `PUBLIC_DOMAIN` is a real hostname (and serves HTTP when it is `:80`). The admin API on `:2019` exposes `/metrics` for Prometheus.

## Consequences

**Easier.**

- **Automatic TLS** — Caddy issues and renews certificates unattended; the most common TLS failure (an expired cert at 03:00) cannot happen.
- Short, declarative configuration — the routing and header policy fit in one screen and read as English.
- Safe defaults — strong TLS, sane timeouts out of the box.
- First-class admin API exposing `/metrics`; Prometheus scrapes it without an exporter.

**Harder.**

- Smaller operator familiarity than nginx in some organizations; shops with deep nginx muscle may prefer the tool they know.
- Fewer low-level knobs than nginx — e.g. upstream tuning, buffer micro-management; traded away for the simplicity above.
- A more youthful ecosystem than nginx for some edge cases (custom load balancing algorithms), though Caddy's plugin model closes most gaps.

**Scope limit — when to revisit.** When the proxy requires fine-grained upstream tuning Caddy lacks, an unusual load-balancing algorithm, or an operator base whose nginx tooling (and runbooks) does not easily translate — re-evaluate against **nginx** or **Traefik**. The growth-ladder reason ("we now have a service mesh") is a separate trigger: a sidecar mesh (Linkerd/Istio) takes the traffic-policy job *off* the ingress, leaving the ingress to route and terminate TLS — at which case Caddy is likely still adequate.

## Alternatives considered

- **nginx** — the incumbent; ubiquitous, deep, fast. Rejected on config ergonomics: achieving automatic TLS requires third-party tooling (certbot, lua, or a companion), and the full config is taller for the same routing. Chosen as the base image for the **frontend** (static serving), where its strengths and that ergonomics trade-off do not apply.
- **Traefik** — excellent ergonomics, automatic Let's Encrypt, a strong fit for containers; a near-tie. Rejected narrowly on "the config holds in my head" — Caddy's `:80`/hostname site-block mechanic was the simpler story for a single-host reference. Traefik is a defensible alternative and the tie-break is taste.

## See also

- [`compose/Caddyfile`](../../compose/Caddyfile) — the routing and security headers
- [../security/tls.md](../security/tls.md) — the TLS story
- [../architecture/service-communication.md](../architecture/service-communication.md) — the routing contract
