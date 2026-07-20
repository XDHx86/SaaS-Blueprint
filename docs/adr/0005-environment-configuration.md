# ADR-0005 — Use `.env` + overlays for configuration

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

Configuration varies by environment; code does not. The repository needs a configuration story that is **honest about the audience** (single-host Compose), **low-friction for a reader**, and **escapable to a secure mechanism** when the fidelity of the reference stops being enough. The choice trades convenience for a separation that must be maintained deliberately.

Forces:

- *Twelve-factor fit* — config belongs in the environment; the image is the same across environments.
- *Reader friction* — `.env.example` + `make bootstrap` must be the whole story for a first run.
- *Secret safety* — the mechanism must name where secrets sit and that they are never baked into images.
- *Upgrade path* — the swap to a real secrets manager must be **local, not architectural**.

## Decision

Use **`.env`** (gitignored) generated from a commented **`.env.example`** template, populated by `make bootstrap`, and consumed via compose `${VAR}` interpolation. Use **compose overlays** (base + local override + prod) for what varies by deployment shape. Secrets (`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `GRAFANA_ADMIN_PASSWORD`) live only in `.env` and enter containers at runtime via `environment:` / `environment_file`.

## Consequences

**Easier.**

- One template is the documentation for every setting — [`docs/architecture/environment-variables.md`](../architecture/environment-variables.md).
- Reproducibility of configuration: the same `.env.example` + `make bootstrap` lands the same shape everywhere.
- `.env` is gitignored; secrets stay out of version control by construction; `.dockerignore` keeps them out of images.

**Harder.**

- Secrets sit in **plaintext** on the dev host's filesystem — acceptable for a single-dev reference, not acceptable for a team or prod.
- No automatic rotation; rotation is a documented manual procedure (see [../security/secrets-management.md](../security/secrets-management.md)).
- Compose `${VAR}` makes values visible in `docker compose config` output; do not print that in shared terminals/CI logs.
- Per-developer forks of `.env` can drift silently; the template + the env-var reference doc are the correction.

**Scope limit — when to revisit.** When secrets are real, shared across a team, or rotated regularly — adopt **SOPS** (encrypted secrets in git) or **Vault** (dynamic, short-lived). The swap is **local, not architectural**: the compose `${VAR}` interpolation stays; what *supplies* the `.env`-equivalent changes (a SOPS-decrypted temp file, or a Vault sidecar writing the env). Nothing in the compose or application code changes. The trigger is "more than one person relies on the secret, or a regulator requires non-disk-at-rest storage."

## Alternatives considered

- **Vault from the start** — correct for prod; rejected here because it requires a running Vault (an infrastructure dependency larger than the system it serves). The reference must boot from a clone; `.env` does that. Vault is the named upgrade path, not the starting point.
- **SOPS from the start** — also viable for a reference, and a stronger starting point than `.env` for orgs already committed to it. Rejected for friction: it adds a decrypt step to the first run. The middle ground — "this repo starts at `.env`, and SOPS is the documented next tier" — is the honest call.

## See also

- [`.env.example`](../../.env.example) — the template
- [../architecture/environment-variables.md](../architecture/environment-variables.md) — the reference table
- [../security/secrets-management.md](../security/secrets-management.md) — rotation and the upgrade tiers
- [`scripts/bootstrap.sh`](../../scripts/bootstrap.sh) — the generator
