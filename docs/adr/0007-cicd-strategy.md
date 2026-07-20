# ADR-0007 — Use GitHub Actions for CI/CD

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

The repository lives on GitHub (this is a portfolio blueprint), so CI/CD must be **native to that platform**, **readable** as separate concerns (lint, test, build, scan, release), and **reusable**. The choice trades hosted-platform familiarity against flexibility.

Forces:

- *Cognitive disconnect cost* — a self-hosted CI adds a new tool a reader must learn before reading the pipeline.
- *Separation of concerns* — lint, test, build, scan, and release are separate workflows, not one mega-job, so each reads on its own.
- *Immutability* — the pipeline must *build and tag* images and *publish* them; prod pulls the artifact, it does not build.
- *Audience* — most readers expect Actions; meeting that expectation is itself a signal of platform awareness.

## Decision

Use **GitHub Actions**, separate workflows per concern, under [`.github/workflows/`](../../.github/workflows/):

| Workflow | Triggers | Purpose |
| --- | --- | --- |
| [`ci.yml`](../../.github/workflows/ci.yml) | push/PR to `main` | shellcheck + compose config (all overlays) + diagram lint + backend tests |
| [`docker.yml`](../../.github/workflows/docker.yml) | push/PR on services/compose | buildx multi-stage builds, caching, image-size reporting — no push |
| [`security.yml`](../../.github/workflows/security.yml) | weekly + manual | image scan (placeholder; non-blocking) |
| [`release.yml`](../../.github/workflows/release.yml) | `v*` tag | build + push to GHCR (tag + `latest`), GitHub Release with changelog excerpt |

Reusable actions (`checkout`, `setup-buildx-action`, `build-push-action`, `trivy-action`) keep each workflow short and the intent obvious.

## Consequences

**Easier.**

- Nothing to host — the pipeline runs where the repository runs; reviewers see status inline.
- **Separation keeps each workflow a story** — read `ci.yml` alone and you have the "does it pass" story; read `release.yml` alone and you have the "publish" story.
- Buildx GHA cache makes repeated builds cheap; the `docker.yml` job surfaces image size so regressions are visible.
- **Immutability is represented**: `release.yml` publishes an immutable image by tag; prod pulls the tag; the host never builds in prod.

**Harder.**

- Hosted-CI lock-in: leaving GitHub means rewriting the workflows.
- The **security scan is a placeholder** (non-blocking); a real policy must set thresholds and route findings before it's trustworthy.
- The release job publishes on any tag — a typo'd tag is a real artifact; tags should be protected (tag-protection rules in repo settings).
- No automatic prod deploy on release — deployment is an operator step gated by health. This is deliberate (see [../operations/deployment.md](../operations/deployment.md)); it is also a "harder" for anyone expecting a fully automated deploy.

**Scope limit — when to revisit.** When shipping from a platform other than GitHub, or when the organization standardizes on GitLab CI / Jenkins / Tekton, the workflows must be ported — the **concerns and order** transfer (lint → test → build → scan → publish), and the tool does not. When full deploy automation is required, add an environment-aware deploy step to `release.yml` (or a separate `deploy.yml`) gated on a health gate — the structure supports it without rework. When traceability (SLSA / image signing) is required, extend `release.yml` with cosign/signing steps.

## Alternatives considered

- **GitLab CI** — excellent, mature; rejected because the repository is on GitHub. A-GitLab-org would port the *concerns* here, not the syntax.
- **Jenkins** — powerful, self-hosted; rejected on the hosted/readability axis and operator overhead. For an org with deep Jenkins investment it remains defensible; not for a GitHub-hosted portfolio.
- **Tekton / a Kubernetes-native pipeline** — correct *above the Compose rung*; rejected here because it presupposes the scheduler this reference deliberately is not.

## See also

- [../operations/deployment.md](../operations/deployment.md) — how a release runs
- [../development/release-strategy.md](../development/release-strategy.md) — tag → image → prod
- [../security/overview.md](../security/overview.md) — the placeholder scanner's role
- `SYSTEM_DESIGN.md` — the **immutability** philosophy this pipeline enacts
