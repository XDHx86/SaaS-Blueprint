# Security — Overview

Security here is a **posture**, not a feature list: least privilege by construction, TLS at the edge, secrets from the environment, and containers that cannot escalate. The reference implementation lives in [`compose/docker-compose.prod.yml`](../../compose/docker-compose.prod.yml); the rationale per control lives in the linked pages and ADRs.

## Threat model (summary)

| Threat | Control | Where |
| --- | --- | --- |
| Secrets leak into images | `.dockerignore` rejects `.env`/keys; config from env at runtime | [secrets-management.md](secrets-management.md) |
| In-flight interception | TLS terminates at Cloudflare; Caddy holds origin cert (ACME) | [tls.md](tls.md) |
| Unauthorized DB/cache access | datastores on `infra-lab-net`, **not** published to host (prod) | [network-security.md](network-security.md) |
| Container escape / privilege | non-root `USER`, `read_only`, `cap_drop: [ALL]`, `no-new-privileges` | [container-security.md](container-security.md) |
| Drift / tampered artifact | images are immutable + pinned by tag; CI scans (placeholder) | [`security.yml`](../../.github/workflows/security.yml) |
| Lost secret durability | `.env` is gitignored; `bootstrap` is idempotent | [secrets-management.md](secrets-management.md) |

## Layering — in both directions

Defense is applied at each layer, and each layer is also a place to *stop depending on* the one below:

1. **Edge** — Cloudflare WAF + CDN + TLS stop a large class of noise before it touches the origin.
2. **Proxy** — Caddy enforces header policy and routes only known paths; nothing reaches the app that the proxy did not allow.
3. **Application** — stateless backend; no process-local secrets; the cache is best-effort.
4. **Data** — Postgres/Redis reachable only on `infra-lab-net`; production overlay closes host ports.
5. **Container** — least-privilege runtime (non-root, read-only, no caps).

If a lower layer fails, the layer above is still in play — e.g. if the edge WAF were bypassed, the proxy still routes only known paths; if a container were compromised, read-only + no caps limits the blast radius.

## Scope and limits

This is a **reference architecture**. It demonstrates the *shape* of a defensible posture, not a hardened deployment of a specific org:

- Image scanning is a **placeholder** (`security.yml` is non-blocking); wire a real policy before relying on it.
- Receivers (Slack/email/PagerDuty) are **placeholders**; configure them.
- `.env` is the dev secret store; the **upgrade path** (SOPS / Vault) is documented, not implemented.

The honesty is the point: each limit is named where it appears, with the trigger to close it. See the per-decision rationale in [docs/adr/](../adr/).

## See also

- [secrets-management.md](secrets-management.md)
- [tls.md](tls.md)
- [network-security.md](network-security.md)
- [container-security.md](container-security.md)
- [`SECURITY.md`](../../SECURITY.md) — reporting a vulnerability
