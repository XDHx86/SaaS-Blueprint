#!/usr/bin/env sh
# =============================================================================
# Infrastructure Lab — composite stack healthcheck
# =============================================================================
# Curls the key endpoints across the running stack and prints a pass/fail map.
# Intended for `make health` and as a deploy-gate primitive in CI.
#
# A readiness 503 is a VALID result for /readyz when a dependency is down — it
# is reported distinctly; only /healthz failures are treated as outages.
#
# Requires: curl. Usage:
#   make health        (or)   sh scripts/healthcheck.sh http://localhost
# =============================================================================
set -euo pipefail

BASE="${1:-http://localhost}"
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

fail=0

probe() {
  label="$1"; url="$2"; want="$3"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null || echo 000)"
  # `want` may be a single code or an alternation joined by '|'.
  case "|${want}|" in
    *"|${code}|"*)
      printf '  \033[32mPASS\033[0m  %-24s %s (HTTP %s)\n' "$label" "$url" "$code"
      ;;
    *)
      printf '  \033[31mFAIL\033[0m  %-24s %s (got %s, want %s)\n' "$label" "$url" "$code" "$want"
      fail=1
      ;;
  esac
}

echo "stack health @ $BASE"
# Critical: the backend liveness reached through Caddy.
probe "backend /healthz"    "$BASE/healthz"      200
# Readiness may legitimately be 503 (dependency down) — report but don't fail.
probe "backend /readyz"     "$BASE/readyz"       "200|503"
probe "backend /api/status"  "$BASE/api/status"  200

# Observability (dev host ports; closed in the prod overlay).
probe "prometheus healthy"   "http://localhost:9090/-/healthy"   200
probe "grafana health"       "http://localhost:3000/api/health" 200
probe "alertmanager healthy" "http://localhost:9093/-/healthy"  200

echo
if [ "$fail" -eq 0 ]; then
  printf 'result: \033[32mALL CRITICAL PASS\033[0m\n'
  exit 0
else
  printf 'result: \033[31mSOME CHECKS FAILED\033[0m\n'
  exit 1
fi
