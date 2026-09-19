#!/usr/bin/env python3
"""Coder-workspace personal-dots resolver.

Resolves which of this repository's dotfiles a Coder workspace should
sync: a fixed set of "core" configs (zsh, nvim, tmux, ...) plus, for
each selected agent client, that client's own settings. This is
personal computing configuration and stays owned by this repository.

Stack-to-tool composition (which packages a workspace needs for stack
X) is NOT this module's concern any more -- that moved to
auto-code-env's stack-install.py, which owns the machine/environment
policy of "what does this Coder workspace need installed" and runs
before this script, using this repository's own Omni tool provider
catalog (settings.d/tools.json) via Omni's native $include mechanism.
Splitting it out this way removed a stack/tool catalog that previously
had to be hand-kept in sync between the two repositories.
"""

import argparse
import copy
import json
from pathlib import Path
import os
import sys
from urllib.parse import urlsplit

HOST = "coder-components"
CORE_DOTS = ["zsh", "zshenv", "zshrc", "env", "tmux", "nvim", "lazygit"]


def choices(value, allowed, name):
    result = []
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        if item not in allowed:
            raise ValueError(f"invalid {name}: {item}")
        if item not in result:
            result.append(item)
    return result


def contract(env):
    clients = choices(env.get("CODER_AGENT_CLIENTS", ""), {"claude", "codex"}, "CODER_AGENT_CLIENTS")
    result = {"clients": clients}
    url = env.get("CODER_MCP_URL", "")
    if url:
        parsed = urlsplit(url)
        if parsed.scheme not in {"http", "https"} or not parsed.hostname or any(ord(c) < 33 for c in url):
            raise ValueError("CODER_MCP_URL must be an explicit HTTP(S) URL")
    result["CODER_MCP_URL"] = url
    return result


def resolve(repo, env):
    selection = contract(env)
    root = repo / "dotfiles/omni/.config/omni"
    settings = json.loads((root / "settings.json").read_text())
    dots = {dot["name"]: dot for group in json.loads((root / "settings.d/dots.json").read_text())["groups"] for dot in group.get("dots", [])}
    client_dots = []
    for client in selection["clients"]:
        dot = {"name": client, "path": dots[client]["path"], "hosts": {HOST: {"package": client + "@coder-components"}}}
        filename = "settings.json" if client == "claude" else "config.toml"
        dot["ignore"] = ["*", "!/" + filename]
        client_dots.append(dot)
    groups = [{"name": "component-clients", "dots": client_dots}]
    resolved_dots = []
    for name in CORE_DOTS:
        dot = copy.deepcopy(dots[name])
        if HOST in dot.get("hosts", {}):
            dot["hosts"] = {HOST: dot["hosts"][HOST]}
        else:
            dot.pop("hosts", None)
        resolved_dots.append(dot)
    groups.append({"name": "component-core-dots", "dots": resolved_dots})
    host_settings = copy.deepcopy(settings["host_settings"][HOST])
    host_settings["dots_repo"] = str(repo)
    return {
        "$schema": settings["$schema"],
        "version": settings["version"],
        "host_settings": {HOST: host_settings},
        "hosts": {HOST: [g["name"] for g in groups]},
        "groups": groups + [{"name": HOST, "special": "host"}],
        "settings": {"fallback_bin_dir": "~/.local/bin", "dots_git": {"auto_commit": False}},
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--contract", action="store_true")
    args = parser.parse_args()
    try:
        config = resolve(args.repo.resolve(), os.environ)
    except (ValueError, OSError, KeyError) as exc:
        parser.error(str(exc))
    if args.contract:
        config = {"version": 1, "selection": contract(os.environ), "configuration": config}
    json.dump(config, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
