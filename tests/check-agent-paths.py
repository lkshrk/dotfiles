#!/usr/bin/env python3
"""Exercise the hook against a real index, including partially staged fixes."""
from pathlib import Path
import subprocess
import tempfile

checker = Path(__file__).resolve().parents[1] / "scripts/check-agent-paths.py"
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    def git(*args):
        return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
    def check(expected):
        result = subprocess.run(["python3", str(checker)], cwd=root, capture_output=True, text=True)
        assert result.returncode == expected, result.stderr
        return result
    git("init", "-q")
    path = root / "dotfiles/codex/.codex/config.toml"
    path.parent.mkdir(parents=True)
    safe = 'command = "sh"\nargs = ["-c", \'exec node "$HOME/tool.mjs"\']\n'
    for local in ["/Users/test/tool", "/home/test/tool", "/root/tool", "/tmp/tool",
                  "/private/var/tool", "/var/folders/tool", "/Volumes/disk/tool",
                  "/opt/homebrew/bin/node", "/usr/local/Cellar/node", r"C:\Users\test\tool"]:
        path.write_text(f"path = '{local}'\n")
        git("add", ".")
        path.write_text(safe)
        result = check(1)
        assert local not in result.stderr, "Hook leaked config content"
    git("add", ".")
    path.write_text("path = '/home/unstaged/tool'\n")
    check(0)
    path.write_text('paths = ["~/tool", "$HOME/tool", "/bin/sh", "/usr/bin/env", "/etc/config"]\n')
    git("add", ".")
    check(0)
    claude = root / "dotfiles/claude/.claude/settings.json"
    claude.parent.mkdir(parents=True)
    claude.write_text('{"env":{"ROOT":"/home/test/plugin"}}\n')
    git("add", ".")
    check(1)
    git("rm", "-f", str(claude))
    check(0)
    host = root / "dotfiles/codex@host/.codex/config.toml"
    host.parent.mkdir(parents=True)
    host.write_text("path = '/home/host/tool'\n")
    git("add", ".")
    check(0)
print("PASS: staged path guard, partial staging, both clients, deletions and explicit host packages")
