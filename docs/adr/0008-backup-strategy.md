# ADR-0008 — Use `pg_dump` for backups

- **Status:** Accepted
- **Date:** 2026-07-20

## Context

The system's durable state is PostgreSQL. A reference backup must be **simple, believable, and operable** — it must *demonstrate the loop* (take a backup, drill a restore), even if it is not the mechanism a large production would run. The choice trades simplicity for RPO/RTO capability.

Forces:

- *Understandability* — a backup the reader cannot trace end-to-end is a hope, not a backup.
- *Operational integrity* — the restore must be drillable, and the drill must be cheap.
- *Upgrade clarity* — the limits must be named so the operator knows when to move.
- *Honest scope* — a portfolio reference must not imply it runs continuous WAL.

## Decision

Use **`pg_dump`** for logical backups: a nightly dump of `${POSTGRES_DB}`, gzipped and timestamped into `./backups/`, with `BACKUP_RETENTION_DAYS` pruning (default 7). Restore replays the dump via `psql` after a confirmation prompt. See [`scripts/backup.sh`](../../scripts/backup.sh) and [`scripts/restore.sh`](../../scripts/restore.sh).

## Consequences

**Easier.**

- The mechanism is **a single pipeline** (`pg_dump | gzip > file`); a reader traces it end-to-end in one screen.
- **A restore drill is cheap** — bring up a throwaway stack, `make restore`, verify, tear down (see [../operations/backup-restore.md](../operations/backup-restore.md)).
- No WAL-archiving coordination complexity; no separate WAL storage to manage.
- The dump is portable across Postgres versions (logical format), reducing migration risk.

**Harder.**

- **Point-in-time recovery is impossible** — the RPO is "last nightly dump." Uncommitted work between snapshots is lost on restore.
- **Restore of a large DB is slow** — replaying SQL is slower than restoring files; for large DBs this crosses an RTO threshold.
- No incremental/parallel backup; the dump cost scales with DB size.
- No continuous archiving means no snapshot beyond `pg_dump`'s view; the backup window is observable as a brief lock during `pg_dump`.

**Scope limit — when to revisit.** Switch to **continuous WAL archiving** (pgBackRest or WAL-G) when any of:

- **RPO < nightly** — the business cannot lose a day's writes.
- **RTO too long with `pg_dump` replay** — a restore drill shows the replay exceeds the recovery target.
- **DB size makes `pg_dump` windows intrusive** — the dump lock or duration is observable in the busy hours.

The upgrade shape (pgBackRest / WAL-G) is the same logical model: take a base backup, archive WAL continuously, PITR on restore — a slide from snapshot to continuous, not a rewrite of the operational loop. The trigger to leave `pg_dump` is a measurement (restore-drill RTO, RPO requirement, or intrusion window), not assumption.

## Alternatives considered

- **pgBackRest from the start** — correct for prod; rejected here because it requires configuring a repository, splitting full/incr/WAL storage, and an operational surface larger than the dump-demonstration purpose. Named as the upgrade path.
- **WAL-G** — equivalent to pgBackRest with cloud-archival focus; same reasoning. A defensible alternative the operator selects when moving continuous.
- **Cloud-managed backup / snapshot** (e.g. RDS snapshots) — out of scope: this reference runs its own Postgres. The lesson transfers — a managed Postgres replaces this whole ADR if adoption shifts hosting.

## See also

- [../operations/backup-restore.md](../operations/backup-restore.md) — the runbook and the drill
- [`scripts/backup.sh`](../../scripts/backup.sh), [`scripts/restore.sh`](../../scripts/restore.sh)
- [0002](0002-use-postgresql.md) — what is backed up
