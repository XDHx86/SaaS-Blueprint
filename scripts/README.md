# Scripts

Operational one-shots, all POSIX sh (`#!/usr/bin/env bash`) with `set -euo pipefail`. They are safe to re-run **with one destructive exception** — `restore.sh` overwrites the database and prompts for confirmation.

Each script is the reference implementation of an operational practice documented under [docs/operations/](../docs/operations/).

| Script | What it does | `make` target |
| --- | --- | --- |
| [`bootstrap.sh`](bootstrap.sh) | generate strong secrets into `.env`, preflight checks, idempotent | `make bootstrap` |
| [`backup.sh`](backup.sh) | `pg_dump` → gzipped, timestamped dump in `./backups/`, applies retention | `make backup` |
| [`restore.sh`](restore.sh) | restore a dump via `psql`, confirmation prompts, `--yes` to bypass | `make restore FILE=…` |
| [`healthcheck.sh`](healthcheck.sh) | composite endpoint probe across the running stack | `make health` |
| [`lint.sh`](lint.sh) | `shellcheck` + `compose config` for all overlays + diagram lint | `make lint` |

## Safety posture

- **Idempotent** except `restore.sh`. Re-running `bootstrap.sh` preserves existing secrets; it only fills *blank* fields.
- **Shell discipline.** `set -euo pipefail` everywhere — a failure in a pipeline fails the script; an unset variable fails it too.
- **No magic.** Streams work over `docker compose exec -T` (TTY disabled) so pipes behave the same in CI and locally.
- **Destructive actions prompt.** Restore requires you to type the database name to confirm. Pass `--yes` only in scripted contexts where you have already gated the call.

## Running standalone

The `make` targets are thin wrappers. Each script `cd`s to the repo root from its own location, so you can run `sh scripts/backup.sh` from anywhere.

## Dependency notes

- `curl` is required for `healthcheck.sh` (the busybox `wget` fallback was removed to keep the code honest).
- `shellcheck` and `mmdc` are optional; their absence is reported but non-fatal. CI installs them (see `.github/workflows/ci.yml`) for full coverage.
- Backups land in `./backups/` (gitignored except `.gitkeep`). Ensure the host path is on a volume with enough headroom for the dump + retention window.

## See also

- [docs/operations/backup-restore.md](../docs/operations/backup-restore.md)
- [docs/operations/deployment.md](../docs/operations/deployment.md)
- [ADR-0008](../docs/adr/0008-backup-strategy.md) — `pg_dump` vs WAL-G/pgBackRest
