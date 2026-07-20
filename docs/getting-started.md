# Getting Started

End-to-end in about five minutes. Prerequisites, bring-up, verification.

## Prerequisites

- **Docker** with the Compose v2 plugin (`docker compose version` should print a v2 version)
- **GNU Make**
- **curl**
- A POSIX shell (the scripts target `/bin/sh`; `make` invokes `bash`)
- About 2 GiB of free memory

## 1. Configure

```bash
git clone <this-repo> infrastructure-lab
cd infrastructure-lab
cp .env.example .env
make bootstrap
```

`bootstrap` does not copy the file — you did that with `cp` above. It fills the **blank** secret fields in `.env` (`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `GRAFANA_ADMIN_PASSWORD`) with strong random values and runs preflight checks. It is idempotent: re-running it preserves any value you already set. **Run bootstrap before the first `make up`** so the Postgres volume initializes with the generated password.

## 2. Run

```bash
make up
make ps          # every service should report (healthy)
```

`make up` is `docker compose -f compose/docker-compose.yml -f compose/docker-compose.override.yml up -d --build`. The override applies local dev conveniences automatically.

## 3. Verify

```bash
curl http://localhost/healthz          # backend liveness (via Caddy)
curl http://localhost/readyz           # backend readiness (200 once DB+cache up)
curl http://localhost/api/status        # JSON the frontend renders
```

Open the browser:

- **http://localhost/** — frontend status board (live health against the backend)
- **http://localhost:3000/** — Grafana (admin / the password from `.env`)
- **http://localhost:9090/** — Prometheus targets and alerts

If `/readyz` returns **503**, a dependency is not yet healthy — wait and retry. A 503 there is *valid*, not an error in the system.

## 4. Operations

```bash
make backup                          # pg_dump into ./backups (timestamped)
make restore FILE=backups/infra-lab-<ts>.sql.gz   # prompts to confirm
make health                          # composite endpoint probe
make down                            # stop and remove containers (data kept)
make nuke                            # DESTRUCTIVE: also removes named volumes
```

## 5. Develop

Edit backend sources under `services/backend/src/` — the local override mounts them read-only; rebuild restarts to pick up changes:

```bash
make restart        # or: docker compose -f compose/docker-compose.yml restart backend
make logs           # tail logs
make test           # backend suite in a throwaway container
```

## Common issues

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `make up` and services stay `unhealthy` | first run before `make bootstrap` | `cp .env.example .env && make bootstrap`, then `make up` |
| `/readyz` returns 503 | a datastore is still starting or down | `docker compose -f compose/docker-compose.yml ps`; wait or inspect logs |
| Port 80/443 already in use | another process bound those host ports | stop it, or remap the ports in `compose/docker-compose.yml` |
| Permission denied writing to `./backups` | host dir not writable by your user | `chmod`/ACLs the directory; the script writes from the host, not the container |
| `make prod-up` does not scale to replicas | deploy.replicas needs `--compatibility` | the Makefile already passes it; if running compose manually, add `--compatibility` |

## See also

- [architecture/overview.md](architecture/overview.md) — what you just brought up
- [operations/deployment.md](operations/deployment.md) — bring-up in detail
- [operations/health-checks.md](operations/health-checks.md) — the liveness/readiness split
- [development/local-development.md](development/local-development.md) — the override explained
