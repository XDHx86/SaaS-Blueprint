# Compose

One base, two context overlays, one platform overlay — one mental model. The split is the **overlay pattern**: a shared base carries everything needed to run; two overlays change *context* (local conveniences, production assumptions); a third changes *platform* (Windows host mounts), applied automatically only on Windows. Every overlay layers on the base rather than forking it.

## Files

| File | When it applies | What it changes |
| --- | --- | --- |
| [`docker-compose.yml`](docker-compose.yml) | always | the **base** — all services, volumes, network, health endpoints |
| [`docker-compose.override.yml`](docker-compose.override.yml) | `make up` (applied automatically) | local dev: source mount, debug logging |
| [`docker-compose.prod.yml`](docker-compose.prod.yml) | `make prod-up` | prod: pinned registry images (no build), hardening, replicas, closed datastores |
| [`docker-compose.windows.yml`](docker-compose.windows.yml) | `make` on Windows (`OS=Windows_NT`); not loaded on Linux/macOS | Windows: node-exporter rootfs bind without `rslave` propagation (Docker Desktop lacks it) |

The [`Caddyfile`](Caddyfile) is the reverse-proxy config, bind-mounted into the `proxy` service. It is config, not a build artifact.

## Platform overlay (Windows)

The base `node-exporter` bind-mounts the host rootfs with `rslave` mount propagation so it sees host filesystem changes. Docker Desktop on Windows does not support `rslave`, so [`docker-compose.windows.yml`](docker-compose.windows.yml) swaps the root mount for a plain `ro` bind. The [`Makefile`](../Makefile) includes it **only on Windows** (detected via `OS=Windows_NT`); on Linux/macOS the `-f` list omits it entirely, so behaviour there is unchanged.

```yaml
services:
  node-exporter:
    volumes: !override          # REPLACE the base mounts — don't append (avoids double-binding /host)
      - "/:/host:ro"            # no rslave — Docker Desktop on Windows does not support it
      - "/proc:/host/proc:ro"
      - "/sys:/host/sys:ro"
```

> Caveat: without `rslave`, host filesystem change events are not propagated, so some `node-exporter` metrics may be unavailable on Windows. This is the documented best-effort trade-off — the override keeps the container booting where the base would error.

## Why overlays (and not three independent files)

Every environment shares the same service names, internal ports, health endpoints, and volume names. Only *context* varies:

- **Local dev** wants source mounts and verbose logs; it tolerates building from source.
- **Production** wants pinned images pulled from a registry, hardening, replicas, and no host-exposed datastores.

Encoding both in one file would mean conditionals the reader has to mentally resolve. Three files where each overlay *only* states what differs keeps the base a faithful description of the system and makes the production posture auditable in its own file.

## How overlays merge

Compose merges the base with each overlay by **service name**; overlay keys replace base keys of the same name. To *remove* a base key in prod (e.g. the `ports:` we publish on the dev postgres, or the `build:` block), the overlay uses the `!reset` extension from spec:

```yaml
postgres:
  ports: !reset null      # remove the dev host port published in the base
backend:
  build:  !reset null     # do not build in prod; pull the image instead
```

`!reset null` is supported in the modern Compose v2 CLI used by `make`.

Note that `volumes` are **append-merged** by default: a second `volumes:` list extends the base's rather than replacing it. The Windows overlay therefore uses the `!override` extension to *replace* the base `node-exporter` mounts wholesale — otherwise `/host`, `/host/proc` and `/host/sys` would be double-bound and fail to start. `!override` is the same Compose spec family as `!reset`.

## Expectations & differences from the trusted-template style

- `make up` builds from source and applies the override automatically (filename matches the default override pattern).
- `make prod-up` pulls pinned images and **does not build** — use `--compatibility`, tracked tasks from there honor `deploy.replicas`.
  Spec equivalent (what `make prod-up` runs):
  ```bash
  docker compose --compatibility --env-file .env \
    -f compose/docker-compose.yml -f compose/docker-compose.prod.yml up -d
  ```
- Validate any composition renders to what you expect:
  ```bash
  docker compose --compatibility --env-file .env \
    -f compose/docker-compose.yml -f compose/docker-compose.prod.yml config | less
  ```

- On Windows, `make` additionally appends `compose/docker-compose.windows.yml` to every `-f` list (detected via `OS=Windows_NT`); on Linux/macOS it is omitted. The hand-written examples above are the Linux/macOS form — to reproduce a Windows run, append `-f compose/docker-compose.windows.yml` yourself.

## Locked conventions

Names and ports are shared with every other surface (`.env.example`, `docs/architecture/environment-variables.md`, ADRs). Change a name here and you must change it there; the reconciliation pass in the workflow catches drift.

## See also

- [docs/architecture/networking.md](../docs/architecture/networking.md) — subnets, host vs internal ports, egress
- [docs/security/container-security.md](../docs/security/container-security.md) — the hardening this overlay enforces
- [BACKEND_DOCKERFILE](../services/backend/Dockerfile) + [FRONTEND_DOCKERFILE](../services/frontend/Dockerfile) — image build provenance
- [ADR-0001](../docs/adr/0001-use-docker-compose.md) — why Compose and not Kubernetes
- [ADR-0005](../docs/adr/0005-environment-configuration.md) — configuration strategy across environments
