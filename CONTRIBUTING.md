# Contributing

Thanks for considering a contribution. Infrastructure Lab is a **reference architecture**, so contributions should improve the blueprint's *clarity*, *correctness*, or *coverage* — not add product features.

## Scope

**In scope:**
- Architecture and documentation improvements, new ADRs, refined diagrams.
- Better operational scripts, health checks, and observability.
- Compose-overlay correctness, CI/CD, and security hardening.
- Keeping the documented growth ladder honest (the Kubernetes/Terraform rungs).

**Out of scope:**
- Application or business logic in `services/` beyond the minimal reference.
- Bindings to a specific organization's fleet, registry, or secrets manager.

## Getting started

```bash
cp .env.example .env
make bootstrap      # generate secrets + preflight
make up             # bring up the stack
make ps             # everything (healthy)
make lint           # shellcheck + compose config
make test           # backend test suite
```

Prerequisites: Docker (with Compose v2), `make`, and `curl`. See [docs/getting-started.md](docs/getting-started.md).

## Branching & commits

- **Trunk-based** with short-lived branches: `feat/…`, `fix/…`, `docs/…`, `chore/…`.
- Use [Conventional Commits](https://www.conventionalcommits.org/) prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- If a change touches a decision, **reference the ADR** in the commit body (e.g., `See ADR-0004`).

## Before opening a PR

- [ ] `make lint` passes (shellcheck + `compose config` for all overlays).
- [ ] `make test` passes (backend suite).
- [ ] The stack still boots: `make up && make ps` shows all services healthy.
- [ ] Cross-links resolve and the [README file tree](README.md#repository-structure) still matches reality.
- [ ] If you added a setting, it appears in `.env.example` *and* [docs/architecture/environment-variables.md](docs/architecture/environment-variables.md).

## Diagrams & ADRs

- **Diagrams-as-code.** Edit the `.mmd` sources in [architecture/diagrams/](architecture/diagrams/). The README and docs embed the rendered graphs — keep them in sync. Render locally with `mmdc` if you change graph layout.
- **New ADR.** Copy the template in [docs/adr/README.md](docs/adr/README.md); use the next sequential number; explain Context → Decision → Consequences. Update the ADR index.

## Changelog

Add your change under the **[Unreleased]** section of [CHANGELOG.md](CHANGELOG.md). A maintainer cuts releases on tag creation (see the release workflow and [docs/development/release-strategy.md](docs/development/release-strategy.md)).

## Style

- Match the surrounding file's tone and density: terse, practical, no marketing language.
- Shell scripts use POSIX sh, `set -euo pipefail`, and a help/usage on misuse.
- Keep documents scannable: short paragraphs, tables for enumerated values, a "See also" footer.
