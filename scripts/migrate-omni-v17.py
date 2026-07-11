#!/usr/bin/env python3
"""Migrate omni settings.json to v17 layout and structured install recipes.

Transforms a monolithic v16 settings.json (or a bloated v17 root file) into:

  settings.json          — version, $include, settings, host_settings, hosts, ignore
  settings.d/agents.json
  settings.d/groups.json — ai-plugins uses @agents.* refs
  settings.d/tools.json  — script fallbacks converted to recipes where possible

Usage:
  ./scripts/migrate-omni-v17.py                     # migrate in place
  ./scripts/migrate-omni-v17.py --dry-run           # print planned paths only
  ./scripts/migrate-omni-v17.py --input settings.json.bak
  ./scripts/migrate-omni-v17.py --compact           # only strip root duplicates

Omni also ships:
  omni settings migrate-host-overrides   # fold tools.*.hosts → providers[]
  omni settings lint                     # verify after migration

Requires omni >= ffd2f31 for full recipe materialization (tag_name, arch_map, etc.).
"""

from __future__ import annotations

import argparse
import json
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SETTINGS = REPO_ROOT / "dotfiles/omni/.config/omni/settings.json"
SETTINGS_DIR_NAME = "settings.d"

ROOT_ONLY_KEYS = ("settings", "host_settings", "hosts", "ignore")
FRAGMENT_KEYS = ("agents", "groups", "tools")

ARCH_MAP_DEFAULT = "aarch64:arm64,x86_64:x86_64,arm64:arm64,amd64:x86_64"
ARCH_MAP_YQ = "aarch64:linux_arm64,x86_64:linux_amd64,arm64:linux_arm64,amd64:linux_amd64"


def recipe_curl(url: str, *, check_path: str | None = None, env: str | None = None, uninstall: str | None = None) -> dict[str, Any]:
    opts: dict[str, str] = {"url": url}
    if check_path:
        opts["check_path"] = check_path
    if env:
        opts["env"] = env
    if uninstall:
        opts["uninstall"] = uninstall
    return {"provider": "script", "recipe": {"type": "curl_install_script"}, "options": opts}


def recipe_github(
    owner: str,
    repo: str,
    asset_pattern: str,
    *,
    bin_name: str | None = None,
    tag_name: str | None = None,
    arch_map: str | None = None,
    extract_dir: str | None = None,
    strip_components: str | None = None,
    uninstall: str | None = None,
) -> dict[str, Any]:
    spec: dict[str, Any] = {
        "provider": "script",
        "source": {"type": "github", "owner": owner, "repo": repo},
        "recipe": {"type": "github_release_asset", "asset_pattern": asset_pattern},
    }
    if tag_name:
        spec["recipe"]["tag_name"] = tag_name
    if bin_name:
        spec["bin"] = bin_name
    opts: dict[str, str] = {}
    if arch_map:
        opts["arch_map"] = arch_map
    if extract_dir:
        opts["extract_dir"] = extract_dir
    if strip_components:
        opts["strip_components"] = strip_components
    if uninstall:
        opts["uninstall"] = uninstall
    if opts:
        spec["options"] = opts
    return spec


def recipe_apt_repo(key_url: str, signed_by: str, sources_format: str, packages: str) -> dict[str, Any]:
    return {
        "provider": "script",
        "recipe": {"type": "apt_repo"},
        "options": {
            "key_url": key_url,
            "signed_by": signed_by,
            "sources_format": sources_format,
            "packages": packages,
        },
    }


TOOL_RECIPE_SPECS: dict[str, dict[str, Any]] = {
    "bun": recipe_curl("https://bun.sh/install", check_path="$HOME/.bun/bin/bun", uninstall="rm -rf $HOME/.bun"),
    "uv": recipe_curl(
        "https://astral.sh/uv/install.sh",
        check_path="uv",
        env='UV_INSTALL_DIR="$HOME/.local/bin"',
        uninstall="rm -f $HOME/.local/bin/uv",
    ),
    "grok": recipe_curl("https://x.ai/cli/install.sh", check_path="grok", uninstall="rm -rf $HOME/.grok/bin"),
    "eza": recipe_github("eza-community", "eza", "eza_{arch}-unknown-linux-gnu.tar.gz", bin_name="eza"),
    "docker": recipe_apt_repo(
        "https://download.docker.com/linux/ubuntu/gpg",
        "/etc/apt/keyrings/docker.asc",
        "Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: {suite}\nComponents: stable\nArchitectures: $(dpkg --print-architecture)\nSigned-By: /etc/apt/keyrings/docker.asc",
        "docker-ce-cli docker-buildx-plugin docker-compose-plugin",
    ),
    "gh": recipe_apt_repo(
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg",
        "/etc/apt/keyrings/githubcli-archive-keyring.gpg",
        "deb [arch={arch} signed-by={signed_by}] https://cli.github.com/packages stable main",
        "gh",
    ),
    "lazygit": recipe_github(
        "jesseduffield", "lazygit", "lazygit_0.62.2_linux_{arch}.tar.gz",
        bin_name="lazygit", tag_name="v0.62.2", arch_map=ARCH_MAP_DEFAULT,
    ),
    "glow": recipe_github(
        "charmbracelet", "glow", "glow_2.1.2_Linux_{arch}.tar.gz",
        bin_name="glow", tag_name="v2.1.2", arch_map=ARCH_MAP_DEFAULT,
    ),
    "vhs": recipe_github(
        "charmbracelet", "vhs", "vhs_0.11.0_Linux_{arch}.tar.gz",
        bin_name="vhs", tag_name="v0.11.0", arch_map=ARCH_MAP_DEFAULT,
    ),
    "yamlfmt": recipe_github(
        "google", "yamlfmt", "yamlfmt_0.21.0_Linux_{arch}.tar.gz",
        bin_name="yamlfmt", tag_name="v0.21.0", arch_map=ARCH_MAP_DEFAULT,
    ),
    "yq": recipe_github("mikefarah", "yq", "yq_{arch}", bin_name="yq", arch_map=ARCH_MAP_YQ),
    "omni": recipe_github("lkshrk", "omni", "omni_{os}_{arch}.tar.gz", bin_name="omni", arch_map=ARCH_MAP_DEFAULT),
    "neovim": recipe_github(
        "neovim", "neovim", "nvim-linux-{arch}.tar.gz",
        bin_name="nvim",
        arch_map=ARCH_MAP_DEFAULT,
        extract_dir="$HOME/.local",
        strip_components="1",
        uninstall="rm -rf $HOME/.local/bin/nvim $HOME/.local/lib/nvim $HOME/.local/share/nvim/runtime",
    ),
}


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, data: dict[str, Any], *, dry_run: bool) -> None:
    if dry_run:
        print(f"would write {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def replace_script_provider(tool: dict[str, Any], recipe_provider: dict[str, Any]) -> bool:
    providers = tool.get("providers", [])
    out: list[dict[str, Any]] = []
    replaced = False
    for provider in providers:
        if provider.get("provider") == "script" and not replaced:
            merged = deepcopy(recipe_provider)
            if provider.get("bin_dir"):
                merged["bin_dir"] = provider["bin_dir"]
            out.append(merged)
            replaced = True
        else:
            out.append(provider)
    if replaced:
        tool["providers"] = out
    return replaced


def convert_tool_recipes(tools: dict[str, Any]) -> list[str]:
    changed: list[str] = []
    for name, spec in TOOL_RECIPE_SPECS.items():
        if name not in tools:
            continue
        if replace_script_provider(tools[name], spec):
            changed.append(name)
    return changed


def fix_script_hygiene(tools: dict[str, Any]) -> list[str]:
    """Remove upgrade/install divergence and fold oh-my-zsh upgrade into install."""
    changed: list[str] = []
    oh_my_zsh_upgrade = (
        "(cd $HOME/.oh-my-zsh && git pull --quiet); "
        'for p in zsh-autosuggestions zsh-syntax-highlighting; do '
        'git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$p" pull --quiet; done'
    )
    for name, tool in tools.items():
        providers = tool.get("providers") or []
        for provider in providers:
            if provider.get("provider") != "script":
                continue
            opts = provider.setdefault("options", {})
            if name == "oh-my-zsh" and oh_my_zsh_upgrade not in opts.get("install", ""):
                opts["install"] = opts.get("install", "").rstrip("; ") + "; " + oh_my_zsh_upgrade
                opts.pop("upgrade", None)
                changed.append(name)
            elif opts.get("upgrade") and opts.get("upgrade") != opts.get("install"):
                opts.pop("upgrade", None)
                changed.append(name)
    return changed


def update_ai_plugins_group(groups: list[dict[str, Any]]) -> bool:
    for group in groups:
        if group.get("name") == "ai-plugins":
            group["skills"] = ["@agents.packages"]
            group["mcp_servers"] = ["@agents.mcp_servers"]
            group["plugins"] = ["@agents.plugins"]
            group["marketplaces"] = ["@agents.marketplaces"]
            return True
    return False


def merge_loaded_config(main_path: Path, cfg: dict[str, Any]) -> dict[str, Any]:
    """Merge $include fragments if present (idempotent re-run support)."""
    include = cfg.get("$include") or []
    base = main_path.parent
    merged = deepcopy(cfg)
    for rel in include:
        fragment_path = base / rel
        if not fragment_path.is_file():
            continue
        fragment = load_json(fragment_path)
        for key in FRAGMENT_KEYS:
            if key in fragment and fragment[key]:
                if key not in merged or not merged.get(key):
                    merged[key] = fragment[key]
    return merged


def compact_root(cfg: dict[str, Any]) -> dict[str, Any]:
    """Keep only root-level keys; fragments hold agents/groups/tools."""
    out: dict[str, Any] = {
        "$schema": "https://raw.githubusercontent.com/lkshrk/omni/main/spec/omni.settings.v17.schema.json",
        "version": 17,
        "$include": [
            f"{SETTINGS_DIR_NAME}/agents.json",
            f"{SETTINGS_DIR_NAME}/groups.json",
            f"{SETTINGS_DIR_NAME}/tools.json",
        ],
    }
    for key in ROOT_ONLY_KEYS:
        if key in cfg:
            out[key] = cfg[key]
    return out


def migrate(cfg: dict[str, Any], *, compact_only: bool) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any], list[str]]:
    notes: list[str] = []
    if not compact_only:
        recipe_changes = convert_tool_recipes(cfg.get("tools", {}))
        if recipe_changes:
            notes.append(f"converted script providers to recipes: {', '.join(sorted(recipe_changes))}")
        hygiene = fix_script_hygiene(cfg.get("tools", {}))
        if hygiene:
            notes.append(f"fixed script hygiene: {', '.join(sorted(set(hygiene)))}")
        if update_ai_plugins_group(cfg.get("groups", [])):
            notes.append("ai-plugins group now uses @agents.* refs")

    agents = cfg.get("agents", {})
    groups = cfg.get("groups", [])
    tools = cfg.get("tools", {})
    main = compact_root(cfg)
    return main, {"agents": agents}, {"groups": groups}, {"tools": tools}, notes


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", type=Path, default=DEFAULT_SETTINGS, help="settings.json path")
    parser.add_argument("--dry-run", action="store_true", help="show actions without writing")
    parser.add_argument(
        "--compact",
        action="store_true",
        help="only remove duplicate agents/groups/tools from root (re-split fragments unchanged)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    settings_path: Path = args.input.resolve()
    if not settings_path.is_file():
        print(f"error: {settings_path} not found", file=sys.stderr)
        return 1

    cfg = merge_loaded_config(settings_path, load_json(settings_path))
    settings_dir = settings_path.parent / SETTINGS_DIR_NAME

    main_cfg, agents_frag, groups_frag, tools_frag, notes = migrate(cfg, compact_only=args.compact)

    if args.dry_run:
        print(f"input:  {settings_path}")
        print(f"output: {settings_path}")
        print(f"        {settings_dir}/agents.json")
        print(f"        {settings_dir}/groups.json")
        print(f"        {settings_dir}/tools.json")
        for note in notes:
            print(f"  - {note}")
        return 0

    write_json(settings_path, main_cfg, dry_run=False)
    write_json(settings_dir / "agents.json", agents_frag, dry_run=False)
    write_json(settings_dir / "groups.json", groups_frag, dry_run=False)
    write_json(settings_dir / "tools.json", tools_frag, dry_run=False)

    print(f"migrated {settings_path}")
    for note in notes:
        print(f"  - {note}")
    print("next: omni settings lint --config", settings_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())