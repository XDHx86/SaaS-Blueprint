# Frontend — `infra-lab-frontend`

A static status board served by nginx. It has no build step and no framework — the assets in `public/` are copied directly into the image. Its job is to *visibly prove the wiring*: it fetches the backend endpoints through Caddy and renders live health.

## What it shows

- **Backend liveness** (`/healthz`) — is the backend process answering?
- **Backend readiness** (`/readyz`) — are the backend's dependencies (Postgres + Redis) reachable?
- **Backend status** (`/api/status`) — JSON the page renders verbatim, including build commit and request count.

A readiness of `NOT READY` is a **valid, expected state** when a dependency is down — distinct from `DOWN` (the process is not answering at all). This distinction is the same one the prod overlay's traffic routing depends on.

## Files

| File | Purpose |
| --- | --- |
| `public/index.html` | page scaffold |
| `public/styles.css` | styles (dark status board) |
| `public/app.js` | fetches `/healthz`, `/readyz`, `/api/status` every 5s |
| `nginx.conf` | site config (SPA fallback, cache headers); copied to `/etc/nginx/conf.d/default.conf` |
| `Dockerfile` | single-stage `nginx:1.27-alpine` build |

## See also

- [backend service](../backend/README.md)
- [service communication](../../docs/architecture/service-communication.md)
- [container strategy](../../docs/architecture/container-strategy.md)
