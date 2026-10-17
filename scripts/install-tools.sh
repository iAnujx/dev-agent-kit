#!/usr/bin/env bash
# Installs the AI agent CLI + free security scanners. Safe to re-run.
set -uo pipefail
BIN="$HOME/.local/bin"; mkdir -p "$BIN"; export PATH="$BIN:$PATH"

echo "== Gemini CLI =="
npm install -g @google/gemini-cli || echo "gemini-cli install failed (check npm)"

echo "== Python scanners + agent deps =="
pip install --quiet --user semgrep pip-audit bandit google-genai python-dotenv

echo "== Gitleaks =="
if ! command -v gitleaks >/dev/null; then
  V=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
  curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${V}/gitleaks_${V}_linux_x64.tar.gz" | tar -xz -C "$BIN" gitleaks
fi

echo "== Trivy =="
if ! command -v trivy >/dev/null; then
  curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "$BIN"
fi

echo "== OSV-Scanner =="
if ! command -v osv-scanner >/dev/null; then
  curl -sSL -o "$BIN/osv-scanner" https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_amd64 \
    && chmod +x "$BIN/osv-scanner"
fi

echo "Done. Versions:"
for t in gemini semgrep gitleaks trivy osv-scanner; do printf '%s: ' "$t"; ($t --version 2>/dev/null || $t version 2>/dev/null || echo MISSING) | head -1; done
