#!/usr/bin/env bash
# =============================================================================
# Infrastructure Lab — restore (PostgreSQL logical restore)
# =============================================================================
# Streams a backup file into the postgres container via psql. Destructive: it
# replays SQL against the current database, so it can overwrite rows. The script
# prompts for confirmation unless --yes is passed.
#
# Usage:
#   make restore FILE=backups/infra-lab-20260720-120000.sql.gz
#   sh scripts/restore.sh backups/infra-lab-20260720-120000.sql.gz [--yes]
#
# Practice a restore on a throwaway database before you need it for real — a
# backup you have never restored is a hope, not a backup. See
# docs/operations/backup-restore.md.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE=".env"
COMPOSE="docker compose -f compose/docker-compose.yml"

[ -f "$ENV_FILE" ] || { echo "no $ENV_FILE found; run 'make bootstrap' first" >&2; exit 1; }
# shellcheck disable=SC1091
set -a; . ./"$ENV_FILE"; set +a

FILE="${1:-}"
ASSUME_YES="${2:-}"

if [ -z "$FILE" ]; then
  echo "usage: $0 <backup-file.sql.gz> [--yes]" >&2
  exit 1
fi
[ -f "$FILE" ] || { echo "backup not found: $FILE" >&2; exit 1; }

cat >&2 <<EOF
WARNING: this replays SQL into database '${POSTGRES_DB:-appdb}' as
user '${POSTGRES_USER:-infra}'. Existing rows may be overwritten or
conflict. Type the database name to confirm, or Ctrl-C to abort.
EOF

if [ "$ASSUME_YES" != "--yes" ]; then
  printf 'confirm database name: ' >&2
  read -r CONFIRM
  if [ "$CONFIRM" != "${POSTGRES_DB:-appdb}" ]; then
    echo "confirmation did not match '${POSTGRES_DB:-appdb}'; aborting" >&2
    exit 1
  fi
fi

echo "restoring $FILE into ${POSTGRES_DB:-appdb} ..."
case "$FILE" in
  *.gz) gunzip -c "$FILE" | $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-infra}" "${POSTGRES_DB:-appdb}" ;;
  *.sql) $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-infra}" "${POSTGRES_DB:-appdb}" < "$FILE" ;;
  *) echo "unrecognized file type: $FILE (expected .sql or .sql.gz)" >&2; exit 1 ;;
esac

echo "restore complete."
exit 0
