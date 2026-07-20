# Services

The minimal, runnable reference services. They exist so `docker compose up` boots the *architecture* — proxy, app, stores, observability — making the system demonstrable, not the application. Business logic is intentionally absent.

## Service contract

| Service | Image base | Build context | Internal port | Health | Depends on |
| --- | --- | --- | --- | --- | --- |
| `backend` | `node:20-alpine` (multi-stage) | `services/backend` | 8080 | `/healthz`, `/readyz`, `/metrics` | postgres, redis |
| `frontend` | `nginx:1.27-alpine` (single stage) | `services/frontend` | 80 | `/` (HTTP 200) | — |

## Backend (`backend/`)

A stateless Fastify API exposing liveness, readiness, application status, and a `/metrics` endpoint in Prometheus exposition format. It traps `SIGTERM`/`SIGINT`, drains in-flight requests, and closes its Postgres pool and Redis client before exiting — the contract that makes rolling updates safe.

- `/healthz` → process is alive (liveness; restart signal).
- `/readyz` → dependencies (Postgres + Redis) reachable (readiness; traffic signal). Returns 503 when either is down.
- `/api/status` → JSON the frontend renders.
- `/metrics` → Prometheus text scraped by the monitoring stack.

See [backend/README.md](backend/README.md).

## Frontend (`frontend/`)

Static assets served by nginx. The page calls the backend through Caddy (`/api/status`, `/healthz`, `/readyz`) to visibly prove the proxy → backend wiring. No build step — assets are copied directly into the image.

See [frontend/README.md](frontend/README.md).

## Build once, run anywhere

Both services are multi- or single-stage Docker builds producing small final images. In dev (`make up`) they are built from source. In prod (`docker-compose.prod.yml`) they are pulled as pinned images from `${REGISTRY}` — the same artifacts CI built and scanned. Nothing about the image changes between environments; only the configuration (environment) does.

## See also

- [docs/architecture/service-communication.md](../docs/architecture/service-communication.md)
- [docs/architecture/container-strategy.md](../docs/architecture/container-strategy.md)
- [docs/operations/health-checks.md](../docs/operations/health-checks.md)
