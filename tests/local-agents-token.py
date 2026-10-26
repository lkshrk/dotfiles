#!/usr/bin/env python3
"""Credential selection checks; uses only fake credentials."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "dotfiles/env/.config/env/bin/local-agents-token"

with tempfile.TemporaryDirectory() as work:
    home = Path(work)
    bin_dir = home / "bin"
    bin_dir.mkdir()
    env = {"HOME": work, "PATH": f"{bin_dir}:{os.environ['PATH']}",
           "XDG_DATA_HOME": str(home / "data"),
           "XDG_CONFIG_HOME": str(home / "config")}
    installed = home / "config/env/bin/local-agents-token"
    installed.parent.mkdir(parents=True)
    installed.symlink_to(HELPER)
    rbw = bin_dir / "rbw"
    rbw.write_text('#!/bin/sh\n[ "$*" = "get --folder ENV local-agents" ] || exit 2\nprintf "vault-token\\n"\n')
    rbw.chmod(0o755)

    def run(script, *args):
        return subprocess.run(["/bin/bash", str(script), *args], env=env,
                              text=True, capture_output=True)

    assert run(HELPER).stdout == "vault-token\n"
    token_file = home / "data/local-agents/token"
    token_file.parent.mkdir(parents=True)
    token_file.write_text("file-token\n")
    assert run(HELPER).stdout == "file-token\n"
    env["LITELLM_API_KEY"] = "env-token"
    assert run(HELPER).stdout == "env-token\n"
    env["LITELLM_API_KEY"] = ""
    token_file.write_text("")
    result = run(HELPER)
    assert result.returncode != 0 and not result.stdout and "empty" in result.stderr
    token_file.unlink()
    rbw.write_text("#!/bin/sh\nexit 0\n")
    result = run(HELPER)
    assert result.returncode != 0 and not result.stdout and "empty" in result.stderr
    rbw.write_text("#!/bin/sh\nexit 1\n")
    result = run(HELPER)
    assert result.returncode != 0 and not result.stdout and "rbw" in result.stderr
    rbw.unlink()
    path = env["PATH"]
    env["PATH"] = str(bin_dir)
    result = run(HELPER)
    env["PATH"] = path
    assert result.returncode != 0 and not result.stdout and "install rbw" in result.stderr

print("gateway token checks passed")
