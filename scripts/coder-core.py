#!/usr/bin/env python3

import argparse
import fnmatch
import json
import os
from pathlib import Path
import subprocess
import time


def check_dots(config, home, require=False):
    repo = Path(config["host_settings"]["coder-components"]["dots_repo"])
    group = next(g for g in config["groups"] if g["name"] == "component-core-dots")
    for dot in group["dots"]:
        package = dot.get("hosts", {}).get("coder-components", {}).get("package", dot["name"])
        root = repo / "dotfiles" / package
        if not root.is_dir():
            root = repo / package
        source = root / dot["path"][2:]
        target = home / dot["path"][2:]
        if source.is_dir() and target.exists():
            if not target.is_dir() or (target.is_symlink() and target.resolve() != source.resolve()):
                raise ValueError(f"required config directory conflict: {target}")
            for local in target.rglob("*"):
                relative = local.relative_to(target)
                if local.is_file() and not (source / relative).exists() and not any(fnmatch.fnmatch(str(relative), pattern) for pattern in dot.get("ignore", [])):
                    raise ValueError(f"unmanaged config preserved; resolve before sync: {local}")
        files = [source] if source.is_file() else sorted(p for p in source.rglob("*") if p.is_file())
        if not files:
            raise ValueError(f"required dot source missing: {source}")
        for path in files:
            relative = path.relative_to(source) if source.is_dir() else Path()
            if any(fnmatch.fnmatch(str(relative), pattern) for pattern in dot.get("ignore", [])):
                continue
            local = target / relative if source.is_dir() else target
            if local.exists() or local.is_symlink():
                if not local.is_file() or local.read_bytes() != path.read_bytes():
                    raise ValueError(f"required config conflict; preserve/resolve locally before retry: {local}")
            elif require:
                raise ValueError(f"required config missing after Omni sync: {local}")


def repo_paths(home, value):
    result = []
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        relative = Path(item)
        if relative.is_absolute() or ".." in relative.parts or relative == Path("."):
            raise ValueError(f"CODER_REPO_DIRS must name repositories relative to HOME: {item}")
        path = home / relative
        if home.resolve() not in path.resolve().parents:
            raise ValueError(f"repository escapes HOME: {item}")
        if path not in result:
            result.append(path)
    return result


def install_hooks(paths, timeout=300):
    for repo in paths:
        deadline = time.monotonic() + timeout
        while not (repo / ".git").exists():
            if time.monotonic() >= deadline:
                raise ValueError(f"repository marker never appeared: {repo}")
            time.sleep(min(5, max(0, deadline - time.monotonic())))
        subprocess.run(["git", "-C", str(repo), "rev-parse", "--git-dir"], check=True, stdout=subprocess.DEVNULL)
        if any((repo / name).is_file() for name in ["lefthook.yml", "lefthook.yaml", ".lefthook.yml", ".lefthook.yaml", "lefthook.toml", ".lefthook.toml", "lefthook.json", ".lefthook.json"]):
            subprocess.run(["lefthook", "install"], cwd=repo, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["check-dots", "verify-dots", "hooks"])
    parser.add_argument("config", type=Path, nargs="?")
    args = parser.parse_args()
    if args.mode == "hooks":
        install_hooks(repo_paths(Path.home(), os.environ.get("CODER_REPO_DIRS", "")))
    else:
        check_dots(json.loads(args.config.read_text()), Path.home(), args.mode == "verify-dots")


if __name__ == "__main__":
    main()
