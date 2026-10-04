#!/usr/bin/env python3
"""Reject host-local paths in staged shared Claude/Codex configuration."""
from pathlib import PurePosixPath
import re
import subprocess
import sys

# Shared system paths (/bin, /usr/bin, /etc) are portable. These roots are not.
LOCAL_PATH = re.compile(
    r"(?<![\w./:-])/(?:Users|home|root|Volumes|private|tmp|var/folders|opt/homebrew|usr/local/Cellar)(?:/|(?=[\s\"']))"
    r"|(?<![\w])[A-Za-z]:[\\/]"
)


def git(*args):
    return subprocess.check_output(["git", *args])


def main():
    failed = False
    paths = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z")
    for raw_path in paths.split(b"\0"):
        if not raw_path:
            continue
        path = raw_path.decode("utf-8", errors="surrogateescape")
        parts = PurePosixPath(path).parts
        if (len(parts) < 4 or parts[0] != "dotfiles"
                or parts[1] not in {"claude", "codex"}
                or PurePosixPath(path).suffix not in {".json", ".toml"}):
            continue
        content = git("show", f":{path}").decode("utf-8")
        for number, line in enumerate(content.splitlines(), 1):
            if LOCAL_PATH.search(line):
                # Don't print config contents: the same line could hold a secret.
                print(f"{path}:{number}: host-local path in staged shared config", file=sys.stderr)
                failed = True
    if failed:
        print("Use runtime home expansion, or keep machine-specific state in the local config.", file=sys.stderr)
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
