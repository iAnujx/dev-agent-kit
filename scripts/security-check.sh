#!/usr/bin/env bash
# One command = full static security sweep. Exit code 1 if any blocking check fails.
# Usage: bash scripts/security-check.sh [target_dir]   (default: workspace/ if it has files, else .)
export PATH="$HOME/.local/bin:$PATH"
TARGET="${1:-.}"
FAIL=0
if [ -d "$TARGET" ] && [ -z "$(find "$TARGET" -type f ! -name .gitkeep -print -quit)" ]; then
  echo "Nothing to scan in $TARGET (empty). Build something first."; exit 0
fi
run() { # name, command...
  local name="$1"; shift
  echo; echo "=== $name ==="
  if ! command -v "$1" >/dev/null 2>&1; then echo "FAIL: $1 not installed - run scripts/install-tools.sh"; FAIL=1; return; fi
  if "$@"; then echo "PASS: $name"; else echo "FAIL: $name"; FAIL=1; fi
}

run "Secrets (gitleaks)"        gitleaks detect --source "$TARGET" --no-git --no-banner --redact
run "SAST (semgrep)"            semgrep scan --config auto --error --quiet "$TARGET"
if [ -n "$(find "$TARGET" \( -name package-lock.json -o -name yarn.lock -o -name pnpm-lock.yaml -o -name requirements.txt -o -name poetry.lock -o -name go.sum -o -name Cargo.lock \) -not -path '*/node_modules/*' -print -quit)" ]; then
  run "Dependencies (osv-scanner)" osv-scanner scan -r "$TARGET"
else
  echo; echo "=== Dependencies (osv-scanner) ==="; echo "SKIP: no lockfile/manifest found (npm install first to create package-lock.json)"
fi
run "Containers/IaC (trivy)"    trivy fs --skip-dirs '**/node_modules' --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --exit-code 1 --quiet "$TARGET"

if [ -f "$TARGET/package.json" ] && [ -f "$TARGET/package-lock.json" ]; then
  echo; echo "=== npm audit ==="
  (cd "$TARGET" && npm audit --audit-level=high) && echo "PASS: npm audit" || { echo "FAIL: npm audit"; FAIL=1; }
fi
if ls "$TARGET"/requirements*.txt >/dev/null 2>&1; then
  run "Python deps (pip-audit)" pip-audit -r "$TARGET/requirements.txt"
  run "Python SAST (bandit)"    bandit -r "$TARGET" -ll -q
fi

echo; [ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SECURITY CHECK FAILED - fix findings above"
exit $FAIL~