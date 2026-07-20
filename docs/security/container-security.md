# Security — Container Security

The image establishes the *build* posture; the production overlay enforces the *runtime* posture. Both halves are expressed in code — none of it is "remember to do this."

## The runtime controls (production overlay)

The reference implementation in [`compose/docker-compose.prod.yml`](../../compose/docker-compose.prod.yml):

| Control | Purpose |
| --- | --- |
| `read_only: true` | the root filesystem is immutable — a compromised process cannot write backdoored binaries |
| `tmpfs: /tmp` | the one writable path services actually need, in memory, gone on restart |
| `cap_drop: [ALL]` | no Linux capabilities by default — start from zero |
| `security_opt: no-new-privileges` | a process cannot escalate via setuid binaries or caps |
| non-root `USER` (Dockerfile) | the process doesn't run as root in the first place |
| resource limits (`memory`, `cpus`) | one runaway service cannot starve the others |
| single `cap_add` (frontend: `NET_BIND_SERVICE`) | the **one** capability nginx needs to bind :80 — drop all, then add back the minimum |
| `pull_policy: always` + pinned tag | prod runs the scanned, immutable image, not a locally-built guess |

## Drop all, then add back the minimum

The single most important principle: **`cap_drop: [ALL]`** is the default, and capabilities are added back **one at a time** as the only acceptable reason. nginx binding :80 is the worked example — it gets `NET_BIND_SERVICE` and nothing else. If a future service needs a cap, the PR that adds it must justify it in the same place; "drop all, hope for the best" is the failure mode this avoids.

## Image design for a small surface

[`services/backend/Dockerfile`](../../services/backend/Dockerfile) and [`services/frontend/Dockerfile`](../../services/frontend/Dockerfile):

- **Multi-stage** for the backend: build tools, dev deps, and the npm cache never reach the runtime image.
- **alpine** base for both: small footprint, fewer packages to patch.
- **No dev dependencies** in the runtime image (`npm install --omit=dev` / `NODE_ENV=production`).
- **No secrets baked in**: `.dockerignore` rejects `.env`, `*.key`, `*.pem`.

The obvious further step — a **distroless** runtime image — removes the shell entirely (no `sh`, no package manager, no upgrade path for an attacker who lands in the image). It is not used here because the backend's container `HEALTHCHECK` uses `wget` from busybox; going distroless is an exercise described in the roadmap/to-do's of adopting a static binary (Go). The Node reference keeps the shell for the healthcheck; the principle, not the choice, is what transfers.

## What the healthcheck sees

The backend's `HEALTHCHECK` runs `wget /healthz` inside the container. It confirms the **process served a response** — it does not confirm the system is correct. For correctness across the path, use the composite [`scripts/healthcheck.sh`](../../scripts/healthcheck.sh) which probes through Caddy. See [operations/health-checks.md](../operations/health-checks.md).

## Limits (named)

- alpine still has a shell and a package manager; **distroless** is the real attack-surface floor.
- The CI scanner is a **placeholder** ([`security.yml`](../../.github/workflows/security.yml)); wire real thresholds + SARIF upload before relying on it.
- Resource limits in compose are **approximate** and host-shared; for guaranteed isolation, run on a scheduler that bins-packs (the rung above).

## See also

- [`compose/docker-compose.prod.yml`](../../compose/docker-compose.prod.yml) — the reference implementation
- [../architecture/container-strategy.md](../architecture/container-strategy.md) — how images get small
- [secrets-management.md](secrets-management.md) — secrets never enter the image
- [`SECURITY.md`](../../SECURITY.md) — reporting
