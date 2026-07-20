#!/usr/bin/env bash
# =============================================================================
# Infrastructure Lab — bootstrap
# =============================================================================
# Fills the BLANK secret fields in .env with strong random values and runs
# preflight checks. Idempotent: existing non-empty values are preserved, so it
# is safe to re-run. Run BEFORE the first `make up` so the Postgres volume
# initializes with the generated password.
#
# Usage:  make bootstrap      (or)   sh scripts/bootstrap.sh
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE=".env"
EXAMPLE=".env.example"

# --- preflight --------------------------------------------------------------
need() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing required command: $1" >&2; exit 1; }
}
need docker
need sed
need grep

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose (v2 plugin) is required" >&2
  exit 1
fi

# --- .env from template -----------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  if [ ! -f "$EXAMPLE" ]; then
    echo "neither $ENV_FILE nor $EXAMPLE found; nothing to bootstrap from" >&2
    exit 1
  fi
  echo "creating $ENV_FILE from $EXAMPLE"
  cp "$EXAMPLE" "$ENV_FILE"
fi

# --- a random secret generator ----------------------------------------------
rand() {
  # Prefer openssl; fall back to /dev/urandom + base64.
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n'
  else
    head -c 24 /dev/urandom | base64 | tr -d '\n'
  fi
}

# Fill KEY only if its .env line is present AND empty; preserve anything set.
fill_if_empty() {
  key="$1"
  if grep -q "^${key}=$" "$ENV_FILE"; then
    val="$(rand)"
    # base64 alphabet is safe with a '|' sed delimiter.
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    echo "  set  ${key}"
  elif grep -q "^${key}=" "$ENV_FILE"; then
    echo "  keep ${key} (already set)"
  else
    val="$(rand)"
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
    echo "  add  ${key}"
  fi
}

echo "secrets:"
fill_if_empty POSTGRES_PASSWORD
fill_if_empty REDIS_PASSWORD
fill_if_empty GRAFANA_ADMIN_PASSWORD

# --- ensure runtime dirs ----------------------------------------------------
mkdir -p backups
[ -f backups/.gitkeep ] || touch backups/.gitkeep

echo "preflight:"
# .env validity: every required key present and DB password non-empty.
for key in COMPOSE_PROJECT_NAME POSTGRES_USER POSTGRES_DB POSTGRES_PASSWORD; do
  grep -q "^${key}=" "$ENV_FILE" || { echo "  missing $key in $ENV_FILE" >&2; exit 1; }
done

# Warn (not fail) if a secret is still empty after bootstrap.
# shellcheck disable=SC2034
empty_secret=0
for key in POSTGRES_PASSWORD REDIS_PASSWORD GRAFANA_ADMIN_PASSWORD; do
  if grep -q "^${key}=$" "$ENV_FILE"; then
    echo "  warn: $key is empty — datastores will run without auth" >&2
    # shellcheck disable=SC2034
    empty_secret=1
  fi
done

echo "  compose config   $(docker compose -f compose/docker-compose.yml config -q && echo OK || echo FAIL)"

cat <<EOF

next steps:
  make up        # build and start the stack
  make ps        # every service should report (healthy)
  curl http://localhost/healthz
EOF

exit 0
