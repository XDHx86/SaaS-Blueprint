# Security — Network Security

The network posture is **least privilege by default**: published ports are an explicit opt-in, and the production overlay removes the dangerous ones. Everything else is reachable only inside `infra-lab-net`.

## The rule: close by default

| Port category | Dev (base + override) | Prod (overlay) |
| --- | --- | --- |
| Edge (`80`, `443`) | published | published |
| Datastores (5432, 6379) | Postgres published for DB-client convenience; Redis internal | **not published** |
| Observability (9090, 3000, 9093) | published for dev access | **not published** |
| Admin (Caddy `:2019`) | internal (used by Prometheus) | internal |

The base file's `ports:` mapping is the **dev convenience**; the production overlay uses `ports: !reset null` to remove them entirely. Nothing about the runtime contract changes — only what is reachable from the host.

## Why datastores are closed

A published `5432` is a published Postgres on the host network. On a single dev machine behind a firewall that is a calculated convenience; on anything reachable from the internet it is an exposed credential prompt and, absent auth, an open database. Redis with **no published port** and `requirepass` set by `bootstrap` is reachable only from services already inside `infra-lab-net` — the backend and the exporter — which is the actual set of clients.

## What "reachability" means in compose

Compose service-to-service networking is **flat** inside the project's network: any service can reach any other by name. There is no per-service egress or pairwise allowlist in Compose. The boundaries you *can* enforce:

- **Host exposure** — `ports:` vs `expose:` (and the prod overlay's removal). This is the main lever and it is used.
- **Network membership** — you could define a second network (e.g. `mgmt`) and attach only the observability services, isolating them from the app plane. Not done here, for a single-host reference; the trigger is "isolation, not addressability, becomes the requirement."
- **Host firewall / platform policy** — egress allowlists and origin-IP allowlisting (Cloudflare ranges on `443`) are platform/firewall concerns; compose is not the place and this repo does not pretend otherwise.

## Origin reachability in real prod

If `PUBLIC_DOMAIN` is a real hostname, the origin's `:443` is on the internet — that is the point. The accompanying hardening:

1. **Allowlist Cloudflare's IP ranges** on the origin's `443` at the host firewall, so only Cloudflare can reach Caddy (Cloudflare docs).
2. Keep datastores and observability **unpublished** (the overlay already does).
3. Rely on **Cloudflare Access / a VPN** for Grafana/Alertmanager in prod, not on a published port with a password.

## The honest limit

The flat in-project network means a compromised `frontend` can still `curl postgres:5432` if it had a Postgres client. Real pairwise isolation needs **network policies** — Kubernetes NetworkPolicy or a service mesh — the rung above Compose. Each ADR's Consequences names this as the trigger, not a defect.

## See also

- [container-security.md](container-security.md) — blast-radius reduction at the process
- [tls.md](tls.md) — what protects the hop that *is* exposed
- [../architecture/networking.md](../architecture/networking.md) — the network in detail
- [ADR-0001](../adr/0001-use-docker-compose.md) — single-network trade-off
