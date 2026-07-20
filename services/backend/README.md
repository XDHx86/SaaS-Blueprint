# Backend — `infra-lab-backend`

Minimal Fastify reference API: health, readiness, status, metrics, and graceful shutdown. No business logic — the point is to demonstrate the *contract* a stateless backend should have when it runs behind a reverse proxy in a compose stack.

## Endpoints

| Method | Path | Purpose | Success | Failure |
| --- | --- | --- | --- | --- |
| GET | `/healthz` | liveness — the process answered | 200 | — |
| GET | `/readyz` | readiness — Postgres + Redis reachable | 200 | 503 |
| GET | `/api/status` | JSON status for the frontend | 200 | — |
| GET | `/metrics` | Prometheus exposition | 200 | — |

## Configuration (environment)

| Variable | Default | Used for |
| --- | --- | --- |
| `BACKEND_PORT` | `8080` | listen port (internal) |
| `POSTGRES_HOST` | `postgres` | compose service name |
| `POSTGRES_PORT` | `5432` | — |
| `POSTGRES_USER` | `infra` | — |
| `POSTGRES_PASSWORD` | _(empty)_ | — |
| `POSTGRES_DB` | `appdb` | — |
| `REDIS_HOST` | `redis` | compose service name |
| `REDIS_PORT` | `6379` | — |
| `REDIS_PASSWORD` | _(empty)_ | — |
| `COMMIT_SHA` | `dev` | build label in `/api/status` & `/metrics` |
| `LOG_LEVEL` | `info` | pino log level |
| `SHUTDOWN_TIMEOUT_MS` | `10000` | hard cap for graceful drain |

## Run & test

```bash
make test          # run the suite in a throwaway container (node --test)
make up            # bring up the whole stack; backend reachable via Caddy
curl http://localhost/healthz
```

`npm start` from this directory runs the server directly (Node 20+), but it expects the compose dependencies to be resolvable — use `make up` for the realistic path.

## Design notes

- **No lockfile committed** (this is a reference). The Dockerfile runs `npm install --omit=dev` at build time. For real use, commit `package-lock.json` and switch to `npm ci` (see the note in the Dockerfile).
- **Graceful shutdown**: `SIGTERM`/`SIGINT` → `server.close()` (drains in-flight) → `onClose` ends the Postgres pool and quits Redis → exit within `SHUTDOWN_TIMEOUT_MS` (else forced). Enables zero-drop rolling updates.
- **Readiness ≠ liveness**: `/readyz` returns 503 when a dependency is down, so the proxy stops sending traffic *without* the container being restarted — avoiding cascade restarts across replicas.
- **Metrics without a client library**: `/metrics` emits Prometheus text directly, keeping the dependency footprint to `fastify`, `pg`, `redis`.
- **Background Redis connect**: the HTTP server listens immediately; Redis connects in the background so a slow cache never blocks the health endpoint. Readiness reflects the cache state on each scrape.

## See also

- [docker compose wiring](../../compose/docker-compose.yml)
- [health checks](../../docs/operations/health-checks.md)
- [container strategy](../../docs/architecture/container-strategy.md)
