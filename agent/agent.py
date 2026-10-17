"""
Minimal self-built dev agent (Gemini API, free tier compatible).
Run:  python agent/agent.py
Needs: GEMINI_API_KEY in env or .env (free key from aistudio.google.com)
Safety: file access is jailed to workspace/, shell commands are allowlisted or need your approval.
"""
import os, shlex, subprocess, sys
from pathlib import Path
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()
ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "workspace"
WORK.mkdir(exist_ok=True)
MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")  # change if Google has newer free models
AUTO_OK = ("ls", "cat", "pwd", "node", "npm test", "npm run", "npm install", "pytest", "python", "git status", "git diff")
BLOCKED = ("rm -rf /", "sudo", "curl | sh", "mkfs", ":(){", "chmod -R 777 /")

def _safe(path: str) -> Path:
    p = (WORK / path).resolve()
    if WORK.resolve() not in p.parents and p != WORK.resolve():
        raise ValueError("Path escapes workspace/")
    return p

def list_files(path: str = ".") -> str:
    """List files under a folder inside workspace/ (relative path)."""
    p = _safe(path)
    if not p.exists():
        return "not found"
    skip = {"node_modules", ".git", "__pycache__", "dist"}
    out = []
    for f in sorted(p.rglob("*")):
        if not any(s in f.parts for s in skip) and f.is_file():
            out.append(str(f.relative_to(WORK)))
    return "\n".join(out[:300]) or "(empty)"

def read_file(path: str) -> str:
    """Read a text file inside workspace/ (relative path)."""
    p = _safe(path)
    return p.read_text(errors="replace")[:20000] if p.is_file() else "not found"

def write_file(path: str, content: str) -> str:
    """Create or overwrite a file inside workspace/ with the given content."""
    p = _safe(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)
    return f"wrote {path} ({len(content)} chars)"

def run_command(command: str, cwd: str = ".") -> str:
    """Run a shell command inside workspace/ (cwd relative). Risky commands require human approval."""
    if any(b in command for b in BLOCKED):
        return "BLOCKED: command not allowed"
    if not command.strip().startswith(AUTO_OK):
        ans = input(f"\n[approval] run `{command}` in {cwd}? [y/N] ").strip().lower()
        if ans != "y":
            return "DENIED by user"
    try:
        r = subprocess.run(command, shell=True, cwd=_safe(cwd), capture_output=True, text=True, timeout=300)
        return f"exit={r.returncode}\n{(r.stdout + r.stderr)[-6000:]}"
    except subprocess.TimeoutExpired:
        return "timeout after 300s"

def security_check(project: str) -> str:
    """Run the full security scan on workspace/<project>. Returns scanner output."""
    r = subprocess.run(["bash", str(ROOT / "scripts/security-check.sh"), str(_safe(project))],
                       capture_output=True, text=True, timeout=900)
    return f"exit={r.returncode}\n{(r.stdout + r.stderr)[-8000:]}"

def main():
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        sys.exit("Set GEMINI_API_KEY (free key: aistudio.google.com)")
    client = genai.Client(api_key=key)
    rules = (ROOT / "GEMINI.md").read_text()
    config = types.GenerateContentConfig(
        system_instruction=rules,
        tools=[list_files, read_file, write_file, run_command, security_check],
        automatic_function_calling=types.AutomaticFunctionCallingConfig(maximum_remote_calls=40),
    )
    chat = client.chats.create(model=MODEL, config=config)
    print(f"Dev agent ready ({MODEL}). Type a task, or 'exit'.")
    while True:
        task = input("\nyou> ").strip()
        if task in ("exit", "quit"):
            break
        if task:
            print("\nagent>", chat.send_message(task).text)

if __name__ == "__main__":
    main()
