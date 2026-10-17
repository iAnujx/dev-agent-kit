#!/usr/bin/env bash
# Scans a RUNNING app you own. Usage: bash scripts/dast-zap.sh http://localhost:3000
# Needs Docker. In Codespaces, Docker is available. ONLY scan apps you own or have permission to test.
set -e
URL="${1:?Usage: dast-zap.sh <url>}"
mkdir -p reports && chmod 777 reports
docker run --rm --network host -v "$(pwd)/reports:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t "$URL" -r zap-report.html -I
echo "Report: reports/zap-report.html"
