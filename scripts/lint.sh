#!/usr/bin/env sh
# =============================================================================
# Infrastructure Lab — lint
# =============================================================================
# Runs the cheap, fast checks that catch most regressions before a push:
#   1. shellcheck over scripts/*.sh (if available — non-fatal if absent)
#   2. docker compose config validation for every overlay combination
#   3. diagram lint is intentionally a placeholder here; if `mmdc` is present
#      on the host, render each .mmd to catch syntax errors.
#
# Usage:  make lint        (or)   sh scripts/lint.sh
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."
fail=0

echo "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh compose/*.yml 2>/dev/null || fail=1
else
  echo "  shellcheck not installed; skipping. Install for full coverage."
fi

echo "== docker compose config =="
# A real .env is required to validate prod (it references ${REGISTRY}, etc.).
ENV_ARG=""
[ -f .env ] && ENV_ARG="--env-file .env"

check() {
  label="$1"; shift
  if docker compose $ENV_ARG "$@" config -q >/dev/null 2>&1; then
    printf '  \033[32mPASS\033[0m  %s\n' "$label"
  else
    printf '  \033[31mFAIL\033[0m  %s\n' "$label"
    docker compose $ENV_ARG "$@" config >/dev/null 2>&1 || true
    fail=1
  fi
}

check "base"                     -f compose/docker-compose.yml
check "base + local override"    -f compose/docker-compose.yml -f compose/docker-compose.override.yml
check "base + prod (--compatibility)" --compatibility -f compose/docker-compose.yml -f compose/docker-compose.prod.yml

echo "== diagrams (placeholder) =="
if command -v mmdc >/dev/null 2>&1; then
  for f in architecture/diagrams/*.mmd; do
    mmdc -i "$f" -o /dev/null >/dev/null 2>&1 \
      && printf '  \033[32mPASS\033[0m  %s\n' "$f" \
      || { printf '  \033[31mFAIL\033[0m  %s\n' "$f"; fail=1; }
  done
else
  echo "  mmdc not installed; diagram rendering not validated. Install @mermaid-js/mermaid-cli to enable."
fi

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32mlint: PASS\033[0m\n'
  exit 0
else
  printf '\033[31mlint: FAIL\033[0m\n'
  exit 1
fi
