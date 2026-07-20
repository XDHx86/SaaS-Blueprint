# Security — Secrets Management

Secrets are the one configuration a real deployment must protect. The reference uses `.env` (gitignored) for dev and names SOPS / Vault as the production upgrade path. See [ADR-0005](../adr/0005-environment-configuration.md) for the decision.

## The three secrets

| Secret | Used by | Who reads it |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | postgres, backend, postgres-exporter | sets `requirepass`-equivalent at init |
| `REDIS_PASSWORD` | redis, backend, redis-exporter | sets redis `requirepass` |
| `GRAFANA_ADMIN_PASSWORD` | grafana | admin login |

Anything else in `.env.example` is **non-secret configuration** (ports, names, retention, registry path) and is safe to commit in spirit — though it's not, because the template is the source and `.env` is the instance.

## Dev: `.env` + `bootstrap`

- `.env` is **gitignored** (`.gitignore`); only `.env.example` is tracked.
- `make bootstrap` generates the three secrets with `openssl rand -base64 24` and fills the blank fields. It is **idempotent**: re-running preserves any value already set, so it never clobbers a secret in use.
- Secrets are **never** baked into images (`.dockerignore` rejects `.env`, `*.key`, `*.pem`); they enter the container at runtime via `environment:` / `environment_file`.

## Rotating a secret in dev

Rotation here is "change the value and recreate":

```bash
# rotate Postgres
sed -i 's|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=<new>|' .env
make nuke          # DESTRUCTIVE: volume reset OR application of rotation, your call
make up
```

> ⚠️ Changing `POSTGRES_PASSWORD` does **not** affect an existing volume — Postgres read only `POSTGRES_PASSWORD` at first init, not after, so `make nuke` is what actually rotates it. (In production you would rotate Postgres credentials through `ALTER USER`, not by wiping the volume.) For Redis, rotation works by `make down && make up` because the password is a runtime config.

## The production upgrade path

`.env` is a starting point, not a destination. For prod, adopt a tool that keeps secrets **out of plaintext on disk**:

| Tier | Tool | Why |
| --- | --- | --- |
| Small | SOPS + git | encrypted-at-rest secrets in the repo; age/KMS-backed |
| Medium | HashiCorp Vault + sidecar injection | dynamic, short-lived; rotation cheap |
| Platform | Kubernetes secrets + external-secrets | same ideas, scheduler-native |

The compose files use `${VAR}` interpolation, so swapping the plumbing is **local, not architectural**: the overlay reads from `environment_file`, and you change *what supplies that file* — from `.env` to a SOPS-decrypted temp file or Vault output — without touching the compose or app code. This continuity is why the ADR names the upgrade rather than building it in.

## Practices that apply at every tier

- **Don't log secrets.** The backend logs connection *errors* ("redis connect failed") but never the credential. Review log statements before raising levels.
- **Scope secrets to the services that need them.** The base compose passes `REDIS_PASSWORD` to `redis`, `backend`, and `redis-exporter` — and to **nothing else**. Grafana never sees the DB password.
- **Rotate with a plan.** A secret you cannot rotate is a liability. The mechanical steps above are a drill; run them before you have to.

## Limits (named honestly)

- `.env` is plaintext on the dev host. Acceptable for a single-dev reference; not acceptable for a team or prod.
- `make bootstrap` is infallible-enough for dev; in prod, use the tier-appropriate tool's generation, not a shell script.
- No automatic rotation cadence is wired; the docs describe the manual procedure. The trigger to automate is "more than one person relying on the secret."

## See also

- [`.env.example`](../../.env.example) — the template, fully commented
- [container-security.md](container-security.md) — where secrets meet the runtime
- [ADR-0005](../adr/0005-environment-configuration.md) — the decision
