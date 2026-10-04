#!/usr/bin/env python3
"""Check shared agent configs and the home-relative MCP launcher."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib

repo = Path(__file__).resolve().parents[1]
codex_path = repo / "dotfiles/codex/.codex/config.toml"
claude_path = repo / "dotfiles/claude/.claude/settings.json"
codex = tomllib.loads(codex_path.read_text())
claude = json.loads(claude_path.read_text())
for path in (codex_path, claude_path):
    assert not re.search(r"/(?:Users|home)/[^/\s]+", path.read_text()), path
assert "projects" not in codex, "Project trust belongs in the local config"
assert "CLAUDE_PLUGIN_ROOT" not in claude.get("env", {}), "Plugin roots are per plugin"

server = codex["mcp_servers"]["context-mode"]
with tempfile.TemporaryDirectory(prefix="agent config ") as temporary:
    root = Path(temporary)
    node = root / "node"
    node.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
    node.chmod(0o700)
    for home in (root / "mac home", root / "linux home"):
        result = subprocess.run(
            [server["command"], *server["args"]], check=True,
            env={**os.environ, "HOME": str(home), "PATH": f"{root}:/usr/bin:/bin"},
            text=True, capture_output=True,
        )
        assert result.stdout.strip() == str(home / ".apm/apm_modules/mksglu/context-mode/start.mjs")
print("PASS: portable agent templates and MCP launcher with different home paths")
