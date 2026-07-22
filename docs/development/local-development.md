# Development — Local Development Workflow

The dev experience is a one-command bring-up with source mounts and verbose logging, layered on the *same* base file prod runs. What differs is contained entirely in the override.

## The loop

```bash
git checkout -b feat/my-change
cp .env.example .env        # if not already present
make bootstrap             # one-time: secrets + preflight

make up                    # base + override, built from source
make restart               # pick up backend source edits
make logs                  # tail; see your logs in real time

make test                  # backend suite in a throwaway container
make lint                  # shellcheck + compose config + diagram lint
```

## What the override changes (and why)

[`compose/docker-compose.override.yml`](../../compose/docker-compose.override.yml) applies automatically with `make up` because the filename matches the default override pattern relative to that directory. It adds **only** local conveniences and must not change the service contract (ports, health endpoints, volumes):

| Change | Why |
| --- | --- |
| `services/backend/src:/app/src:ro` source mount | edit-on-host, see the change on restart — no rebuild loop |
| `LOG_LEVEL: debug` | verbose logs at dev time; prod runs `warn` |
| `command: ["node", "src/server.js"]` | explicit start (a hook for a future watch/reload tool) |

The override is **read-only on the source** so the host filesystem is the single source of truth — the container never writes back into your repo.

## Adding a convenience

If a tool speeds your loop (e.g. `nodemon`, a test file watcher), wire it into the override, **not** the base. The base is what prod runs; keeping it clean is how prod stays honest. If your convenience requires a volume or port, reconsider — the contract is fixed for a reason.

## Debugging the stack itself

| Symptom | Drill-down |
| --- | --- |
| Service won't go healthy | `docker compose -f compose/docker-compose.yml logs <svc>` then check healthcheck output |
| Backend can't reach Postgres | `make shell`, then `wget -qO- postgres:5432` (expect connection, not data) — confirm the network name resolves |
| Caddy returns 502 | backend or frontend unhealthy; `make ps` and inspect which `depends_on` blocked |
| Override not applied | you ran plain `docker compose ...` without `-f ...override.yml`; use `make up`, or pass both files explicitly |

## Per-developer overrides

`docker-compose.<name>.yml` (or `.local.yml`) is the place for strongly-personal tweaks (a debug port, a local DB GUI). The `.gitignore` ignores `docker-compose.*.local.yml` so your tweaks don't leak. Per-developer files compose on top of the standard override.

## See also

- [branch-strategy.md](branch-strategy.md) — where the changes go next
- [release-strategy.md](release-strategy.md) — how a merged change ships
- [`compose/README.md`](../../compose/README.md) — how the compose files relate
- [../getting-started.md](../getting-started.md) — the first-run path
