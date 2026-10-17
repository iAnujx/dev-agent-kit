# Dev Agent Kit (free, cloud-based)

A personal AI dev agent that plans, builds (frontend + backend + storage), tests, and security-scans projects.
Runs in GitHub Codespaces + Gemini. No powerful laptop needed. Free tiers only.

## Setup (15 minutes)

1. Create a GitHub account. New repo -> upload this kit's contents (or push the folder).
2. Repo page -> **Code -> Codespaces -> Create codespace on main**. First start auto-installs everything
   (Gemini CLI, Semgrep, Gitleaks, Trivy, OSV-Scanner). Wait for the terminal to finish.
3. Verify: `bash scripts/install-tools.sh` prints a version for each tool.
4. Log in to the agent. Pick ONE:
   - **Gemini CLI:** run `gemini`, sign in with your Google account (the one with Gemini Pro).
   - **Own agent:** get a free key at aistudio.google.com, copy `.env.example` to `.env`, paste the key,
     then `pip install -r agent/requirements.txt && python agent/agent.py`.
5. Free-hours tip: **stop the codespace when done** (Codespaces menu -> Stop).

## Use it

In `gemini`, type:

| Command | What it does |
|---|---|
| `/plan a todo app with login` | Writes PLAN.md (spec, data model, routes, threats) |
| `/backend todo-app` | Builds API + SQLite storage + tests |
| `/frontend todo-app` | Builds React UI |
| `/test todo-app` | Writes and runs tests |
| `/secure todo-app` | Runs all scanners, fixes findings, manual OWASP review |
| `/ship <idea>` | Whole pipeline in one go |

Typical flow: `/plan` -> read and approve PLAN.md -> `/backend` -> `/frontend` -> `/test` -> `/secure`.

Generated apps land in `workspace/<name>/`.

## Security layers

| Layer | Tool | When |
|---|---|---|
| Secrets | Gitleaks | Every commit (pre-commit hook) + CI |
| Code flaws (SAST) | Semgrep | `/secure` + CI |
| Vulnerable packages | OSV-Scanner, npm audit, pip-audit | `/secure` + CI |
| Containers / config | Trivy | `/secure` + CI |
| Running app (DAST) | OWASP ZAP | `bash scripts/dast-zap.sh http://localhost:3000` |
| Manual review | Agent vs OWASP Top 10 | `/secure` |

Run everything manually anytime: `bash scripts/security-check.sh workspace/todo-app`

## Free-tier reality

- Gemini free limits and Codespaces free hours change; check current pages. If you hit a limit, wait,
  switch to the other agent (CLI vs `agent.py`), or use Firebase Studio.
- Make the repo public for the most free CI minutes (never commit secrets either way).

## Rules to keep it safe

- Review every diff, especially auth and input validation. Scanners miss logic bugs.
- Only run ZAP against apps you own.
- Never give the agent production credentials. Deploy manually after review.
- If `/commands` or flags differ in your Gemini CLI version, check its docs; the instruction file (GEMINI.md) and scripts work regardless.

## Improve it

Same mistake twice? Add a rule to GEMINI.md. New skill? Add a `.toml` in `.gemini/commands/`.
