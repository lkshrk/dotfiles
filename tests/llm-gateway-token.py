#!/usr/bin/env python3
"""Credential selection and Coder sync checks; uses only fake credentials/SSH."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "dotfiles/env/.config/env/bin/llm-gateway-token"
SYNC = ROOT / "scripts/coder-sync-codex-auth"

with tempfile.TemporaryDirectory() as work:
    home = Path(work)
    bin_dir = home / "bin"
    bin_dir.mkdir()
    env = {"HOME": work, "PATH": f"{bin_dir}:/usr/bin:/bin",
           "XDG_DATA_HOME": str(home / "data"),
           "XDG_CONFIG_HOME": str(home / "config")}
    installed = home / "config/env/bin/llm-gateway-token"
    installed.parent.mkdir(parents=True)
    installed.symlink_to(HELPER)
    rbw = bin_dir / "rbw"
    rbw.write_text('#!/bin/sh\n[ "$*" = "get --folder ENV llm-gateway" ] || exit 2\nprintf "vault-token\\n"\n')
    rbw.chmod(0o755)

    def run(script, *args):
        return subprocess.run(["/bin/bash", str(script), *args], env=env,
                              text=True, capture_output=True)

    assert run(HELPER).stdout == "vault-token\n"
    token_file = home / "data/llm-gateway/token"
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
    result = run(HELPER)
    assert result.returncode != 0 and not result.stdout and "install rbw" in result.stderr

    ssh = bin_dir / "ssh"
    ssh.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$HOME/ssh-args"\ncat > "$HOME/ssh-input"\nexit "${SSH_FAIL:-0}"\n')
    ssh.chmod(0o755)
    env["LITELLM_API_KEY"] = "sync-token"
    for target in ["example.com", "-bad.coder", "bad/path.coder"]:
        assert run(SYNC, target).returncode == 0
        assert not (home / "ssh-args").exists()
    result = run(SYNC, "workspace.coder")
    assert result.returncode == 0 and not result.stdout
    assert (home / "ssh-input").read_text() == "sync-token\n"
    args = (home / "ssh-args").read_text().splitlines()
    assert "PermitLocalCommand=no" in args and "workspace.coder" in args
    assert "auth.json" not in args[-1]
    remote_env = dict(env, XDG_DATA_HOME=str(home / "remote-data"))
    remote = subprocess.run(["/bin/sh", "-c", args[-1]], env=remote_env,
                            input="sync-token\n", text=True, capture_output=True)
    assert remote.returncode == 0, remote.stderr
    remote_token = home / "remote-data/llm-gateway/token"
    assert remote_token.read_text() == "sync-token\n"
    assert remote_token.stat().st_mode & 0o777 == 0o600
    assert remote_token.parent.stat().st_mode & 0o777 == 0o700
    assert list(remote_token.parent.iterdir()) == [remote_token]
    remote = subprocess.run(["/bin/sh", "-c", args[-1]], env=remote_env,
                            input="", text=True, capture_output=True)
    assert remote.returncode != 0
    assert remote_token.read_text() == "sync-token\n"
    assert list(remote_token.parent.iterdir()) == [remote_token]
    env["SSH_FAIL"] = "1"
    result = run(SYNC, "workspace.coder")
    assert result.returncode == 0 and "failed" in result.stderr
    (home / "ssh-args").unlink()
    env.pop("LITELLM_API_KEY")
    result = run(SYNC, "workspace.coder")
    assert result.returncode == 0 and "no gateway credential" in result.stderr
    assert not (home / "ssh-args").exists()

print("gateway token and Coder sync checks passed")
