# Architecture — Container Strategy

How images are built, and why they look the way they do. The strategy is one statement: **the image is the immutable unit of deployment; the environment is the only thing that varies.**

## Build once, run anywhere

| Context | Source | What runs |
| --- | --- | --- |
| Dev / CI | `services/<svc>/Dockerfile` | image built from source, tagged `infra-lab/<svc>:dev` |
| Prod | same Dockerfile, pinned tag | image **pulled** from `${REGISTRY}/infra-lab-<svc>:${IMAGE_TAG}` |

The same Dockerfile produces both. There is no separate prod build, and there is no second image-producing step between environments — the artifact that passed CI is the artifact that runs. See [ADR-0007](../adr/0007-cicd-strategy.md).

## Multi-stage by default

[`services/backend/Dockerfile`](../../services/backend/Dockerfile) is two stages:

1. **Builder** (`node:20-alpine`) — installs production dependencies (`npm install --omit=dev`). Build tools, dev dependencies, and the npm cache stay in this layer and never reach the runtime image.
2. **Runtime** (`node:20-alpine`) — copies only `node_modules`, source, and the manifest. Runs as a non-root user, exposes 8080, and defines a `HEALTHCHECK`.

The frontend ([`services/frontend/Dockerfile`](../../services/frontend/Dockerfile)) is single-stage because there is no build step — static assets are copied straight into the image.

## Layering for cache efficiency

In each Dockerfile, the **least-changing layers copy first**:

- `COPY package.json` before `npm install` → dependency changes invalidate only the install layer, not the source layer.
- `COPY src` last → source edits do not bust the dependency layer.

CI ([`.github/workflows/docker.yml`](../../.github/workflows/docker.yml)) uses buildx GHA cache keyed per service, so a repeat build only re-runs what changed.

## The runtime contract, enforced by the prod overlay

The Dockerfile establishes the *image* posture; the [production overlay](../../compose/docker-compose.prod.yml) enforces the *runtime* posture:

| Control | Dockerfile | Prod overlay |
| --- | --- | --- |
| Non-root `USER` | yes (`app`) | (inherited) |
| `read_only` root filesystem | — | yes |
| `cap_drop: [ALL]` | — | yes |
| `no-new-privileges` | — | yes |
| writable `/tmp` via `tmpfs` | — | yes |
| resource limits | — | yes (`memory`, `cpus`) |
| `HEALTHCHECK` | yes | yes (kept) |

The frontend grants a **single** capability (`NET_BIND_SERVICE`) because nginx binds :80. That *one* capability, not "broad caps," is the rule: drop all, then add back the minimum. See [security/container-security.md](../security/container-security.md).

## What is deliberately *not* in the images

- **Secrets** — `.dockerignore` rejects `.env`, `*.key`, `*.pem`. Configuration comes from the environment at runtime.
- **Tests and dev tools** — `npm install --omit=dev` keeps the runtime image to the production dependency set. Tests run in CI and via `make test`, not in the deployed image.
- **Docs / `.git` / CI** — the root `.dockerignore` strips these so they never enter a context.

## A note on the lockfile

This reference deliberately does **not** commit `package-lock.json`; the Dockerfile runs `npm install`. Real use should commit the lockfile and switch the Dockerfile to `npm ci` for reproducible, verified installs — this is called out in the Dockerfile. The decision is about keeping the reference uncomplicated, not a recommendation to skip lockfiles.

## See also

- [security/container-security.md](../security/container-security.md) — the runtime hardening row in detail
- [operations/deployment.md](../operations/deployment.md) — how the image is promoted
- [ADR-0007](../adr/0007-cicd-strategy.md) — CI/CD and immutability
- `services/backend/Dockerfile`, `services/frontend/Dockerfile` — the sources
