<!-- codebase-memory-mcp:start -->
# Codebase Knowledge Graph (codebase-memory-mcp)

This project uses codebase-memory-mcp to maintain a knowledge graph of the codebase.
ALWAYS prefer MCP graph tools over grep/glob/file-search for code discovery.

## Priority Order
1. `search_graph` — find functions, classes, routes, variables by pattern
2. `trace_path` — trace who calls a function or what it calls
3. `get_code_snippet` — read specific function/class source code
4. `query_graph` — run Cypher queries for complex patterns
5. `get_architecture` — high-level project summary

## When to fall back to grep/glob
- Searching for string literals, error messages, config values
- Searching non-code files (Dockerfiles, shell scripts, configs)
- When MCP tools return insufficient results

## Examples
- Find a handler: `search_graph(name_pattern=".*OrderHandler.*")`
- Who calls it: `trace_path(function_name="OrderHandler", direction="inbound")`
- Read source: `get_code_snippet(qualified_name="pkg/orders.OrderHandler")`
<!-- codebase-memory-mcp:end -->

<!-- knowledge-vault:start -->
# Knowledge vault and code graph

`~/knowledge` is the shared knowledge vault (git repository `lkshrk/knowledge`, Obsidian vault) for every repository under `~/Dev`. Its `AGENTS.md` is the schema; follow it when writing.

## Before working in a repository

- `~/knowledge/scripts/sync.sh` once per session. Exit 1 means uncommitted changes, 2 a rebase conflict: resolve before relying on the vault. Offline (exit 3) is fine.
- Read `~/knowledge/projects/<repo>/<repo>.md` (`<repo>` = directory name under `~/Dev`), then the pages it links whose `paths` overlap the files you will touch. Check `pitfalls/` before changing code in an area that has one.
- Cross-repository knowledge lives in `~/knowledge/{decisions,patterns,pitfalls,runbooks,components,references}/`; search `~/knowledge/index.md` for it.
- For structure (definitions, callers, impact, outlines) use the code graph (codebase-memory MCP) before grepping whole files; grep for strings, config and non-code files.

## After learning something durable

Durable = a root cause, a trap, a decision with its reason, a working procedure, or a correction from the user about the repository — something a future session would otherwise rediscover. Not: one-off typos, session status, anything already in the repository's own docs.

1. Save the evidence as `~/knowledge/raw/sessions/<YYYY-MM-DD>-<repo>-<slug>.md` (what happened, error text, fix, commit or file references).
2. Edit the matching page (or add one) under `projects/<repo>/<category>/` per the vault's `AGENTS.md`: frontmatter with `repo`, `paths`, `sources`, `lifecycle: draft`; link it from the project overview.
3. `cd ~/knowledge && obsidian-wiki memory sync INGEST source=<raw path> project=<repo> --vault "$PWD" && git add -A && git commit -m "ingest: <repo> <slug>" && scripts/sync.sh` — straight to `main`; the vault's hooks run the lints and secret scan, and `sync.sh` rebases and pushes.

Never put secrets, tokens, private hostnames or personal data in the vault. How the user likes to work stays in the agent's own memory, not in the vault.
<!-- knowledge-vault:end -->
