# Operations — Health Checks

Two questions, two checks. Mixing them up is a classic, expensive mistake. Getting them right is what makes rolling updates drop-less.

## Liveness vs readiness

| Check | Question | Failure response | Endpoint (backend) |
| --- | --- | --- | --- |
| **Liveness** | "Is the process alive at all?" | **restart** the container | `GET /healthz` → 200 |
| **Readiness** | "Can I serve traffic right now?" | **stop sending traffic** (do not restart) | `GET /readyz` → 200 / 503 |

The key insight: **readiness returning 503 is not a crash.** A backend that cannot reach Postgres is not *dead* — restarting it will not bring Postgres back, and a rolling restart can cascade into an outage as every replica restarts at once. Readiness removes the container from routing; liveness restarts it. They describe different failures and demand different responses.

## Implementation in this stack

[`services/backend/src/server.js`](../../services/backend/src/server.js):

- `/healthz` — returns `{"status":"ok","uptime_s":...}` with 200. The process answered. Always available unless the event loop is wedged or the process is gone.
- `/readyz` — pings Postgres (`SELECT 1`) and Redis (`PING`). Returns 200 only if **both** succeed; 503 with a per-dependency `checks` map otherwise. This is the **traffic gate**.
- also `/metrics` — Prometheus exposition (not a health check; a scrape target — see [monitoring.md](monitoring.md)).

Each service's `healthcheck` in [`compose/docker-compose.yml`](../../compose/docker-compose.yml) wires these into the orchestrator:

```yaml
backend:
  healthcheck:
    test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/healthz || exit 1"]
```

The proxy (`depends_on: backend: condition: service_healthy`) only starts routing once backend is `healthy`. Bring-up and rollback terminate at this gate, not at "the containers started" — see [deployment.md](deployment.md).

## Composite health

[`scripts/healthcheck.sh`](../../scripts/healthcheck.sh) probes the **stack** through Caddy, not the backend directly — it validates the *full path* the user takes:

| Probe | Endpoint | Expected |
| --- | --- | --- |
| backend liveness | `/healthz` (via Caddy) | 200 |
| backend readiness | `/readyz` (via Caddy) | 200 **or 503** (both valid) |
| backend status | `/api/status` | 200 |
| prometheus | `/-/healthy` | 200 |
| grafana | `/api/health` | 200 |
| alertmanager | `/-/healthy` | 200 |

Readiness 503 is **reported but not failed** — the script distinguishes "a dependency is down" (a known condition) from "the serving path is broken" (an outage). Only critical failures (liveness, status) set a non-zero exit, which is what a CI gate should key on.

## What to avoid

- **One endpoint that returns 200 unless everything is down.** A process can be alive and unable to serve; collapsing the two hides the condition the proxy most needs to know.
- **Restarting on readiness 503.** Reboots that depend on the dependency coming back cascade; let the proxy drain and wait instead.
- **Putting the cache in liveness.** Redis being down is a `warning` (degraded), not a liveness failure; keep the cache out of the restart path.

## See also

- [deployment.md](deployment.md) — how health gates a deploy
- [../architecture/service-communication.md](../architecture/service-communication.md) — the contract between hops
- [monitoring.md](monitoring.md) — alerting on `up`, not on liveness polls
