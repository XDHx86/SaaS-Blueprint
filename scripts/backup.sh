#!/usr/bin/env bash
# =============================================================================
# Infrastructure Lab — backup (PostgreSQL logical dump)
# =============================================================================
# Runs `pg_dump` inside the postgres container and streams a gzipped, timestamped
# dump to ./backups/ on the host. Applies a retention policy (prune files older
# than BACKUP_RETENTION_DAYS).
#
# This is the REFERENCE backup mechanism (pg_dump). For real production use a
# continuous WAL archiver (pgBackRest / WAL-G) — see ADR-0008 and
# docs/operations/backup-restore.md for the upgrade path.
#
# Usage:  make backup        (or)   sh scripts/backup.sh
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE=".env"
COMPOSE="docker compose -f compose/docker-compose.yml"

[ -f "$ENV_FILE" ] || { echo "no $ENV_FILE found; run 'make bootstrap' first" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
. "./$ENV_FILE"
set +a

RETENTION="${BACKUP_RETENTION_DAYS:-7}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="backups/infra-lab-${TS}.sql.gz"
mkdir -p backups

echo "dumping ${POSTGRES_DB:-appdb} from postgres service ..."
# -T disables TTY so the pipe works; stream through gzip to the host file.
$COMPOSE exec -T postgres pg_dump -U "${POSTGRES_USER:-infra}" "${POSTGRES_DB:-appdb}" \
  | gzip > "$OUT"

SIZE="$(wc -c < "$OUT" | tr -d ' ')"
echo "wrote $OUT (${SIZE} bytes)"

# retention: prune dumps older than RETENTION days
if [ "$RETENTION" -gt 0 ] 2>/dev/null; then
  echo "pruning dumps older than ${RETENTION}d ..."
  find backups -maxdepth 1 -name 'infra-lab-*.sql.gz' -type f -mtime +"$RETENTION" -delete
fi

exit 0
