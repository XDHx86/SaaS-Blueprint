# Operations — Backup & Restore

The reference backup is a logical PostgreSQL dump via `pg_dump`. It is the simplest believable mechanism and the deliberate entry point; the ADR names the upgrade path to continuous archiving (pgBackRest / WAL-G) when RPO/RTO requirements demand it. See [ADR-0008](../adr/0008-backup-strategy.md).

## What is backed up

| Component | Backed up? | How |
| --- | --- | --- |
| **PostgreSQL** | yes | `pg_dump` of `${POSTGRES_DB}` → gzipped dump in `./backups/` |
| **Redis** | no | cache is transient and reconstructable; sessions invalidation is acceptable |
| **Grafana / Prometheus config** | in git | dashboards, rules, provisioning files are versioned, not snapshot-backed |
| **Container images** | in registry | immutable images are the backup for binaries |

The rule: back up only what is **durable, irreducible state** — Postgres. Everything else is either in git, reconstruct-able, or immutable.

## Taking a backup

```bash
make backup
```

What it runs ([`scripts/backup.sh`](../../scripts/backup.sh)):

1. `docker compose exec -T postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > ./backups/infra-lab-<timestamp>.sql.gz`
2. prune files older than `BACKUP_RETENTION_DAYS` (default 7).
3. print the output path and byte size.

The `-T` disables the TTY so the pipe behaves the same in CI and on a laptop. Backups land on the host in `./backups/` (gitignored except `.gitkeep`).

## Scheduling

For a single host, a cron entry is the honest scheduler:

```cron
# /etc/cron.d/infra-lab-backup — nightly, off the hour
23 1 * * *  infra  cd /srv/infrastructure-lab && /usr/bin/env make backup >> /var/log/infra-lab-backup.log 2>&1
```

In a container-orchestrated platform, this becomes a scheduled Job. The mechanism (logical dump) does not change; only the trigger does.

## Restore

```bash
make restore FILE=backups/infra-lab-<timestamp>.sql.gz
```

What it runs ([`scripts/restore.sh`](../../scripts/restore.sh)):

1. confirms you typed the database name (or pass `--yes` in scripted contexts)
2. `gunzip -c <file> | docker compose exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB`

Restore is **destructive**: it replays SQL against the current database, so rows may be overwritten or conflict (duplicate-key errors on conflict are expected for a logical replay). For a clean restore, drop and recreate the database first — a choice the operator makes, not the script.

## Restore drill

A backup you have never restored is a hope, not a backup. The recommended drill:

1. Bring up a throwaway stack: `COMPOSE_PROJECT_NAME=infra-lab-drill make up`.
2. Restore a known backup into it: `make restore FILE=...`.
3. Verify row counts / a known record against source-of-truth.
4. Tear down: `COMPOSE_PROJECT_NAME=infra-lab-drill make nuke`.

Run the drill on a cadence (e.g. monthly). If a restore fails in the drill, you found out in practice — not during an incident.

## Limits of `pg_dump` (the upgrade path)

`pg_dump` is a **point-in-time** logical snapshot. Its limits, and when to move past it:

| Need | `pg_dump` | Move to |
| --- | --- | --- |
| RPO ≈ minutes/seconds | ❌ | continuous WAL archiving (pgBackRest / WAL-G) |
| Point-in-time recovery | ❌ | WAL archive + base backup |
| Physical/parallel backup of large DBs | ❌ | pgBackRest (parallel, incremental) |
| Restore speed on large DBs | ❌ | physical restore (restore the files, not replay SQL) |

The trigger to upgrade is a real RPO requirement or DB size making `pg_dump` windows unacceptable. Until then, `pg_dump` is the right reference.

## See also

- [`scripts/backup.sh`](../../scripts/backup.sh), [`scripts/restore.sh`](../../scripts/restore.sh)
- [ADR-0008](../adr/0008-backup-strategy.md) — the decision
- [deployment.md](deployment.md) — what surrounds a data-touching deploy
