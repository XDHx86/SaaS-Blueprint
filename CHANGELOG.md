# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
For the release process, see [docs/development/release-strategy.md](docs/development/release-strategy.md).

## [Unreleased]

### Added
- _Nothing yet._

### Changed
- `make prod-up` and `make prod-config` now pass `--compatibility`, so `deploy.replicas` is honored when bringing up the prod overlay (matches `make lint`, the prod overlay comment, and the env-var reference). Previously replicas were silently ignored.
- `.env.example` documents `LOG_LEVEL`, `COMMIT_SHA`, and `SHUTDOWN_TIMEOUT_MS`, restoring lockstep with `docs/architecture/environment-variables.md` and the compose `x-backend-env` anchor.
- README now renders all four architecture diagrams inline (request flow, CI/CD flow, and observability flow were previously linked only; their `.mmd` sources do not render on GitHub).
- Diagrams corrected for honesty: Caddy's role reads "headers" rather than "rate limit"/"Limits" (rate limiting is an edge concern; the `Caddyfile` sets security headers), and the observability flow no longer references the nonexistent `PROM_SCRAPE_INTERVAL` (the scrape interval is the literal `15s` in `prometheus.yml`).
- Production overlay comment clarifying that Grafana, Prometheus, and Alertmanager are not published to the host in prod (rewritten; the previous text was self-contradictory).
- Local override and related docs no longer claim "hot reload" — the dev loop is a source mount plus `make restart`; nodemon/`node --watch` is a documented per-developer add-on.

### Removed

## [0.1.0] - 2026-07-20

### Added
- **Core stack:** Caddy reverse proxy, nginx frontend, Fastify backend (`/healthz`, `/readyz`, `/api/status`, graceful shutdown), PostgreSQL, Redis.
- **Compose overlays:** dev base (`docker-compose.yml`), local override (source mount + debug logging), hardened production overlay (read-only, cap drop, non-root, resource limits, replicas, unpublished datastores).
- **Observability:** Prometheus (scrape + recording/alert rules), Grafana (provisioned datasource + reference dashboard), Alertmanager (routing).
- **Operations:** `bootstrap`, `backup`, `restore`, `healthcheck`, and `lint` scripts; `Makefile` developer UX.
- **CI/CD:** `ci` (lint + test), `docker` (build validation), `security` (scan placeholder), `release` (tag → GitHub Release) workflows; PR and issue templates.
- **Documentation:** `SYSTEM_DESIGN.md` philosophy doc, `docs/` organized by concern (architecture / operations / security / scaling / development), ADRs 0001–0008, getting-started guide.
- **Architecture (diagrams-as-code):** system overview, request flow, CI/CD flow, observability flow.
