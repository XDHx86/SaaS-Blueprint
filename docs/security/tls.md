# Security — TLS

TLS terminates at the edge; the origin holds its own automatic certificate. Two hops, two certificates, no manual cert handling.

## The two-hop path

```mermaid
flowchart LR
    U([User]) -->|TLS cert A| CF[Cloudflare]
    CF -->|TLS cert B — origin| Caddy[Caddy]
    Caddy --> FE[frontend] & BE[backend]
    FE -.|HTTP internal| Caddy
    BE -.|HTTP internal| Caddy
```

| Hop | Certificate | Managed by |
| --- | --- | --- |
| User ↔ Cloudflare | Cloudflare edge certificate | Cloudflare (automatic) |
| Cloudflare ↔ origin (Caddy) | origin certificate — ACME / Let's Encrypt | **Caddy, automatic** |

Inside `infra-lab-net`, traffic between Caddy and the application/data services is **HTTP** — the network is private (a single host, internal addresses, and the production overlay closes external data ports). There is no plaintext crossing a network boundary that TLS would protect; the boundary is the edge.

## Why automatic TLS at Caddy

Caddy obtains and renews its origin certificate unattended using ACME, and rewrites them on expiry without operator action. This removes the single most common operational failure in TLS: a cert that expires at 03:00 because nobody set a reminder. The Caddyfile just declares the site address; Caddy does the rest.

To enable it, set `PUBLIC_DOMAIN` to a real hostname (and `ACME_EMAIL`):

```
PUBLIC_DOMAIN=app.example.com
ACME_EMAIL=ops@example.com
```

With `PUBLIC_DOMAIN=:80` (the dev default), Caddy serves plain HTTP and skips ACME — so localhost works without DNS.

## Strictness on the edge

| Control | Where | Set in |
| --- | --- | --- |
| HSTS | response header on origin | `compose/Caddyfile` |
| `X-Content-Type-Options: nosniff` | response header | Caddyfile |
| `X-Frame-Options: DENY` | response header | Caddyfile |
| `Referrer-Policy` | response header | Caddyfile |
| WAF / rate limit | edge | Cloudflare (not in this repo) |
| TLS cipher suite policy | edge + Caddy defaults | Cloudflare dashboard; Caddy's defaults are already strong |

Rate limiting and WAF are **edge concerns** (Cloudflare), not origin — enforcing them at Caddy still lets an attacker saturate the connection. The Caddyfile intentionally does not configure rate limiting; see the note in [`compose/Caddyfile`](../../compose/Caddyfile).

## What TLS does not cover here

- **mTLS between origin services** — out of scope on a single private network; it becomes relevant with a service mesh (the top of the [future evolution ladder](../../README.md#future-evolution)).
- **Certificate pinning / client certs** — not used; the origin is reached only from Cloudflare in a real prod setup, which should be enforced by **IP allowlisting** the origin's 443 to Cloudflare's ranges (a platform/firewall concern, configured outside compose).

## See also

- [`compose/Caddyfile`](../../compose/Caddyfile) — the header policy and site block
- [network-security.md](network-security.md) — restricting origin reachability
- [ADR-0004](../adr/0004-reverse-proxy-selection.md) — why Caddy
