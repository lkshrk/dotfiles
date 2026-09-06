#!/usr/bin/env python3

import argparse
import json
import os
from pathlib import Path
import re
import stat
import tempfile
from urllib.parse import urlsplit


def write_local(path, content):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary = tempfile.mkstemp(prefix=".coder-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(content)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def set_toml_section(text, section, key, value):
    header = f"[{section}]"
    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.strip() == header), None)
    entry = f"{key} = {json.dumps(value)}\n"
    if start is None:
        return text.rstrip() + f"\n\n{header}\n" + entry
    end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
    for i in range(start + 1, end):
        if re.match(rf"\s*{re.escape(key)}\s*=", lines[i]):
            lines[i] = entry
            break
    else:
        lines.insert(start + 1, entry)
    return "".join(lines)


def mcp_override(home, url, clients):
    if not url:
        return
    parsed = urlsplit(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or any(ord(c) < 33 for c in url):
        raise ValueError("CODER_MCP_URL must be an explicit HTTP(S) URL")
    codex = home / ".codex/config.toml"
    if "codex" in clients and codex.exists():
        text = set_toml_section(codex.read_text(), "mcp_servers.litellm-tools", "url", url)
        text = set_toml_section(text, "mcp_servers.litellm-tools.env_http_headers", "x-litellm-api-key", "LITELLM_API")
        write_local(codex, text)
    if "claude" in clients:
        path = home / ".claude.json"
        data = json.loads(path.read_text()) if path.exists() else {}
        server = data.setdefault("mcpServers", {}).setdefault("litellm-tools", {})
        server.update({"type": "http", "url": url})
        server.setdefault("headers", {}).setdefault("x-litellm-api-key", "${LITELLM_API}")
        write_local(path, json.dumps(data, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clients", default="claude,codex")
    args = parser.parse_args()
    clients = [client.strip() for client in args.clients.split(",") if client.strip()]
    mcp_override(Path.home(), os.environ.get("CODER_MCP_URL", ""), clients)


if __name__ == "__main__":
    main()
