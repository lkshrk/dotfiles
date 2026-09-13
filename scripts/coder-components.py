#!/usr/bin/env python3

import argparse
import copy
import json
import os
import shlex
from pathlib import Path
import sys
from urllib.parse import urlsplit

HOST = "coder-components"
STACK_TOOLS = {
    "go": ["go", "go-task", "golangci-lint", "gomplate", "gopls"],
    "python": ["uv", "python@3.14", "pyright"],
    "ts": ["nvm", "pnpm", "typescript", "typescript-language-server"],
    "lua": ["lua", "luarocks", "busted", "lua-language-server", "luacheck", "stylua"],
    "rust": ["cargo"],
    "k8s": ["kubernetes-cli", "helm", "kustomize", "krew", "kubectx"],
    "gitops": ["kubernetes-cli", "helm", "flux", "helmfile", "sops"],
    "argo": ["argo"],
    "talos": ["talosctl"],
    "cilium": ["cilium-cli"],
    "cnpg": ["kubernetes-cli", "kubectl-cnpg"],
    "iac": ["opentofu"],
    "containers": ["docker", "skopeo"],
    "quality": ["actionlint", "gitleaks", "bats-core"],
    "terminal-recording": ["ffmpeg", "ttyd", "vhs"],
    "media": ["ffmpeg"],
}
ALIASES = {
    "infra": ["k8s", "gitops", "argo", "talos", "cilium", "cnpg", "iac"],
    "omni": ["terminal-recording"],
}
BASE = ["git", "curl", "ca-certificates", "jq", "stow", "unzip", "xz-utils", "openssl",
        "zsh", "oh-my-zsh", "tmux", "neovim", "lazygit", "lefthook", "direnv", "bat", "eza", "fd", "ripgrep",
        "build-essential", "pkg-config", "libssl-dev", "tree-sitter-cli", "git-delta"]
CORE_DOTS = ["zsh", "zshenv", "zshrc", "env", "tmux", "nvim", "lazygit"]
RUNTIMES = ["nvm", "uv", "cargo", "bun", "go", "lua", "luarocks"]


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
    stacks = choices(env.get("CODER_OMNI_STACKS", ""), set(STACK_TOOLS) | set(ALIASES), "CODER_OMNI_STACKS")
    stacks = list(dict.fromkeys(s for item in stacks for s in ALIASES.get(item, [item])))
    clients = choices(env.get("CODER_AGENT_CLIENTS", ""), {"claude", "codex"}, "CODER_AGENT_CLIENTS")
    result = {"stacks": stacks, "clients": clients}
    for name, default, allowed in [
        ("CODER_AGENT_PLUGINS", "0", {"0", "1"}),
        ("CODER_ENABLE_DIND", "0", {"0", "1"}),
        ("CODER_BACKEND", "kubernetes", {"kubernetes", "docker"}),
    ]:
        value = env.get(name, default)
        if value not in allowed:
            raise ValueError(f"invalid {name}: {value}")
        result[name] = value
    if result["CODER_AGENT_PLUGINS"] == "1" and not clients:
        raise ValueError("CODER_AGENT_PLUGINS=1 requires CODER_AGENT_CLIENTS")
    url = env.get("CODER_MCP_URL", "")
    if url:
        parsed = urlsplit(url)
        if parsed.scheme not in {"http", "https"} or not parsed.hostname or any(ord(c) < 33 for c in url):
            raise ValueError("CODER_MCP_URL must be an explicit HTTP(S) URL")
    result["CODER_MCP_URL"] = url
    return result



def linux_core_providers(repo):
    helper = shlex.quote(str(repo / "scripts/coder-neovim.py"))
    install = (
        "set -eu; case \"$(uname -m)\" in x86_64|amd64) arch=x86_64 ;; aarch64|arm64) arch=arm64 ;; *) exit 1 ;; esac; "
        "tmp=$(mktemp -d); trap 'rm -rf \"$tmp\"' EXIT; "
        "curl -fsSL --proto-redir '=https' https://api.github.com/repos/neovim/neovim/releases/latest -o \"$tmp/release.json\"; "
        "asset=nvim-linux-$arch.tar.gz; "
        "url=$(jq -er --arg name \"$asset\" '.assets[] | select(.name == $name) | .browser_download_url' \"$tmp/release.json\"); "
        "digest=$(jq -er --arg name \"$asset\" '.assets[] | select(.name == $name) | .digest | select(startswith(\"sha256:\")) | ltrimstr(\"sha256:\")' \"$tmp/release.json\"); "
        "curl -fsSL --proto '=https' --proto-redir '=https' \"$url\" -o \"$tmp/nvim.tar.gz\"; "
        f"python3 {helper} \"$tmp/nvim.tar.gz\" \"$digest\""
    )
    def native(owner, repo_name, binary, pattern, arch_map):
        return {"providers": [{"provider": "script", "bin": binary,
            "options": {"arch_map": arch_map},
            "source": {"type": "github", "owner": owner, "repo": repo_name},
            "recipe": {"type": "github_release_asset", "asset_pattern": pattern}}]}
    return {
        "neovim": {"providers": [{"provider": "script", "bin": "nvim", "options": {
            "install": install,
            "check": 'test -x "$HOME/.local/share/coder-neovim/current/bin/nvim" && test -f "$HOME/.local/share/coder-neovim/current/share/nvim/runtime/doc/help.txt" && test -x "$HOME/.local/bin/nvim"',
            "version": '"$HOME/.local/bin/nvim" --version | head -1 | sed "s/^NVIM v//"',
            "latest": "curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -er '.tag_name | ltrimstr(\"v\")'",
        }}]},
        "git-delta": native("dandavison", "delta", "delta", "delta-{version}-{arch}-unknown-linux-gnu.tar.gz", "aarch64:aarch64,arm64:aarch64,x86_64:x86_64,amd64:x86_64"),
        "lefthook": native("evilmartians", "lefthook", "lefthook", "lefthook_{version}_Linux_{arch}.gz", "aarch64:arm64,arm64:arm64,x86_64:x86_64,amd64:x86_64"),
        "tree-sitter-cli": native("tree-sitter", "tree-sitter", "tree-sitter", "tree-sitter-linux-{arch}.gz", "aarch64:arm64,arm64:arm64,x86_64:x64,amd64:x64"),
    }


def resolve(repo, env):
    selection = contract(env)
    root = repo / "dotfiles/omni/.config/omni"
    settings = json.loads((root / "settings.json").read_text())
    tools = json.loads((root / "settings.d/tools.json").read_text())["tools"]
    source_groups = json.loads((root / "settings.d/groups.json").read_text())["groups"]
    dots = {dot["name"]: dot for group in json.loads((root / "settings.d/dots.json").read_text())["groups"] for dot in group.get("dots", [])}
    selected = list(dict.fromkeys(t for s in selection["stacks"] for t in STACK_TOOLS[s]))
    if "claude" in selection["clients"]:
        selected.append("claude-code")
    if "codex" in selection["clients"]:
        selected.extend(["nvm", "bun", "@openai/codex"])
    if selection["CODER_AGENT_PLUGINS"] == "1":
        plugins = next(g["tools"] for g in source_groups if g["name"] == "ai-plugins")
        selected.extend(t for t in plugins if t != "herdr-tether"
                        and not (t == "oh-my-codex" and "codex" not in selection["clients"])
                        and not (t == "ccundo" and "claude" not in selection["clients"]))
        selected.extend(["bun", "nvm"])
    if "pyright" in selected:
        selected.append("nvm")
    selected = [t for t in dict.fromkeys(selected) if t not in BASE]
    groups = [{"name": "component-base", "tools": BASE}]
    for runtime in RUNTIMES:
        if runtime in selected:
            groups.append({"name": "runtime-" + runtime, "tools": [runtime]})
    groups.append({"name": "component-tools", "tools": [t for t in selected if t not in RUNTIMES]})
    client_dots = []
    for client in selection["clients"]:
        dot = {"name": client, "path": dots[client]["path"], "hosts": {HOST: {"package": client + "@coder-components"}}}
        filename = "settings.json" if client == "claude" else "config.toml"
        dot["ignore"] = ["*", "!/" + filename]
        client_dots.append(dot)
    groups.append({"name": "component-clients", "dots": client_dots})
    resolved_dots = []
    for name in CORE_DOTS:
        dot = copy.deepcopy(dots[name])
        if HOST in dot.get("hosts", {}):
            dot["hosts"] = {HOST: dot["hosts"][HOST]}
        else:
            dot.pop("hosts", None)
        resolved_dots.append(dot)
    groups.append({"name": "component-core-dots", "dots": resolved_dots})
    tools.update(linux_core_providers(repo))
    names = list(dict.fromkeys(t for group in groups for t in group.get("tools", [])))
    missing = set(names) - tools.keys()
    if missing:
        raise ValueError("missing Omni tool definitions: " + ", ".join(sorted(missing)))
    host_settings = copy.deepcopy(settings["host_settings"][HOST])
    host_settings["dots_repo"] = str(repo)
    return {
        "$schema": settings["$schema"],
        "version": settings["version"],
        "host_settings": {HOST: host_settings},
        "hosts": {HOST: [g["name"] for g in groups]},
        "groups": groups + [{"name": HOST, "special": "host"}],
        "tools": {name: tools[name] for name in names},
        "settings": {"fallback_bin_dir": "~/.local/bin", "dots_git": {"auto_commit": False}},
    }


def required_commands(config, provider=None):
    aliases = {
        "nvm": ["node", "npm"], "cargo": ["rustc", "cargo"],
        "python@3.14": [], "ca-certificates": [], "libssl-dev": [],
        "build-essential": ["make", "cc", "c++"], "xz-utils": ["xz"],
        "typescript": ["tsc"], "go-task": ["task"], "kubernetes-cli": ["kubectl"],
        "cilium-cli": ["cilium"], "opentofu": ["tofu"],
        "bats-core": ["bats"], "claude-code": ["claude"],
        "@openai/codex": ["codex"], "oh-my-codex": ["omx"],
        "krew": ["kubectl-krew"], "neovim": ["nvim"], "fd": ["fdfind", "fd"],
        "bat": ["batcat", "bat"], "ripgrep": ["rg"], "oh-my-zsh": [], "tree-sitter-cli": ["tree-sitter"], "git-delta": ["delta"],
    }
    return list(dict.fromkeys(binary for group in config["groups"]
                             for tool in group.get("tools", [])
                             if provider is None or any(p["provider"] == provider for p in config["tools"][tool]["providers"])
                             for binary in aliases.get(tool, [tool])))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--required-commands", type=Path)
    parser.add_argument("--required-provider")
    parser.add_argument("--contract", action="store_true")
    args = parser.parse_args()
    if args.required_commands:
        print("\n".join(required_commands(json.loads(args.required_commands.read_text()), args.required_provider)))
        return
    try:
        config = resolve(args.repo.resolve(), os.environ)
    except (ValueError, OSError, KeyError) as exc:
        parser.error(str(exc))
    if args.contract:
        config = {"version": 1, "selection": contract(os.environ),
                  "required_commands": required_commands(config), "configuration": config}
    json.dump(config, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
