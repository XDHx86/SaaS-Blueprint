#!/usr/bin/env bash
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
  shellcheck scripts/*.sh 2>/dev/null || fail=1
else
  echo "  shellcheck not installed; skipping. Install for full coverage."
fi

echo "== docker compose config =="
# A real .env is required to validate prod (it references ${REGISTRY}, etc.).
ENV_ARG=""
[ -f .env ] && ENV_ARG="--env-file .env"

check() {
  label="$1"; shift
  # shellcheck disable=SC2086
  if docker compose $ENV_ARG "$@" config -q >/dev/null 2>&1; then
    printf '  \033[32mPASS\033[0m  %s\n' "$label"
  else
    printf '  \033[31mFAIL\033[0m  %s\n' "$label"
    # shellcheck disable=SC2086
    docker compose $ENV_ARG "$@" config >/dev/null 2>&1 || true
    fail=1
  fi
}

check "base"                     -f compose/docker-compose.yml
check "base + local override"    -f compose/docker-compose.yml -f compose/docker-compose.override.yml
check "base + prod (--compatibility)" --compatibility -f compose/docker-compose.yml -f compose/docker-compose.prod.yml
# Windows platform overlay (node-exporter rslave→ro swap). Validated on every
# host so the override is exercised in CI even though `make` only loads it on
# Windows (CI runs on Ubuntu; Windows contributors can't catch a broken file
# locally). These match what `make up` / `make prod-up` run on Windows.
check "base + windows"            -f compose/docker-compose.yml -f compose/docker-compose.windows.yml
check "base + override + windows" -f compose/docker-compose.yml -f compose/docker-compose.override.yml -f compose/docker-compose.windows.yml
check "base + prod + windows (--compatibility)" --compatibility -f compose/docker-compose.yml -f compose/docker-compose.prod.yml -f compose/docker-compose.windows.yml

echo "== diagrams =="

if [ -d services/backend/node_modules ]; then
  mkdir -p .tmp/mermaid

  for f in architecture/diagrams/*.mmd; do
    output=".tmp/mermaid/$(basename "$f" .mmd).svg"

    if (
      cd services/backend
      npx --no-install mmdc \
          -p ../../puppeteer-config.json \
          -i "../../$f" \
          -o "../../$output"
    ); then
      printf '  \033[32mPASS\033[0m  %s\n' "$f"
    else
      printf '  \033[31mFAIL\033[0m  %s\n' "$f"
      fail=1
    fi

    rm -f "$output"
  done
else
  echo "  backend dependencies not installed; skipping diagrams."
fi

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32mlint: PASS\033[0m\n'
  exit 0
else
  printf '\033[31mlint: FAIL\033[0m\n'
  exit 1
fi
