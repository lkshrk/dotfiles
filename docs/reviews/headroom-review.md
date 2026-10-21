# Headroom review

<!-- markdownlint-disable MD013 -->

Reviewed 2026-07-19 against Headroom `v0.32.0` (2026-07-17) and current `main` commit `6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff`.

## Verdict

Do not integrate Headroom globally yet. Pilot it as a local, loopback-only transport layer for Claude Code CLI first. Leave the existing `AGENTS.md`, `CLAUDE.md`, MCP servers, memory, RTK/context-mode, routing, and model selection unchanged.

For Codex, wait for the release after `v0.32.0` or test only in a disposable CLI profile. The latest release has open Codex WebSocket/Desktop reports, while unreleased `main` already contains a Codex custom-provider fix and changes wrapper defaults. Treat Codex App/Desktop support as experimental rather than production-ready.

Headroom is most useful here as a proxy that compresses long requests before sending them to the existing model provider. Its MCP, memory, learning, code-memory, and context-tool features overlap with the current setup and should remain disabled initially. Headroom documents both proxy-level automatic compression and optional MCP tools for explicit compression/retrieval. [Architecture and feature summary](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/README.md#L48-L86) [MCP versus proxy](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/docs/content/docs/mcp.mdx#L188-L198)

## Compatibility

| Surface | Status | Recommendation |
| --- | --- | --- |
| Claude Code CLI | Supported through `ANTHROPIC_BASE_URL` | Best first pilot. Keep `ENABLE_TOOL_SEARCH=true`. |
| Claude VS Code extension | Known deferred-tool rendering limitation | Do not proxy initially. |
| Claude Remote Control | Unavailable behind a custom base URL | Run those sessions without Headroom. |
| Codex CLI, API-key login | Supported through a custom provider/base URL | Test only after pinning a version; do not make global yet. |
| Codex CLI, ChatGPT login | Explicitly handled using `openai_base_url` plus existing Codex OAuth state | Test only in an isolated profile. Headroom does not replace or validate the OAuth login. |
| Codex App/Desktop | Source contains Desktop-specific request handling; public guidance is incomplete and open issues remain | Experimental. Keep direct until CLI behavior is proven. |
| MCP in Codex surfaces | Codex CLI, IDE, and ChatGPT desktop share MCP configuration | Technically available, but unnecessary for the initial proxy-only pilot. |

Headroom's Claude troubleshooting guide documents the tool-search, VS Code, and Remote Control constraints. [Claude limitations](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/docs/content/docs/troubleshooting.mdx#L145-L203) OpenAI documents that Codex CLI, the IDE extension, and the ChatGPT desktop app share MCP configuration in `~/.codex/config.toml`. [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)

No new model or provider account is required. Normal proxying reuses the existing Anthropic/OpenAI credential and upstream model. Do not enable Headroom's optional model router during the pilot.

## What the wrappers mutate

`headroom wrap` is not purely an environment-variable wrapper.

### `headroom wrap codex` in `v0.32.0`

- Routes the launched process to a local proxy using `OPENAI_BASE_URL` and Codex `--config` overrides. This routing is process-local during an ordinary interactive wrap.
- With ChatGPT login, persistent provider setup must set `openai_base_url`; Codex subscription traffic can otherwise bypass a custom `model_provider`. With API-key login, Headroom omits `requires_openai_auth=true` so it does not force OAuth. [Codex provider injection](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/headroom/cli/wrap.py#L2450-L2533) [Auth detection and provider config](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/headroom/providers/codex/install.py#L39-L90)
- Installs Headroom MCP into `$CODEX_HOME/config.toml` unless `--no-mcp` is supplied.
- Installs/configures TokenSave or Serena code-memory support unless both `--no-tokensave --no-serena` are supplied.
- Installs RTK/lean-ctx and writes guidance into `$CODEX_HOME/AGENTS.md` unless `--no-context-tool` is supplied.
- `--memory` additionally creates project `.headroom/memory.db`, adds memory MCP configuration, and writes project `AGENTS.md` guidance.

These behaviors are visible in the released wrapper implementation. [Codex routing](https://github.com/headroomlabs-ai/headroom/blob/v0.32.0/headroom/cli/wrap.py#L1845-L1905) [Codex MCP, context tool, code memory, and memory setup](https://github.com/headroomlabs-ai/headroom/blob/v0.32.0/headroom/cli/wrap.py#L5111-L5223)

Current unreleased `main` changes the code-memory interface to `--code-memory {serena,tokensave,none}`, makes RTK opt-in, and fixes custom-provider dotted configuration. Do not use those new flags against `v0.32.0`.

### `headroom wrap claude`

- Sets `ANTHROPIC_BASE_URL` and normally `ENABLE_TOOL_SEARCH=true` for the launched process.
- Writes project `.claude/settings.local.json` so subprocesses use the proxy, then restores the base URL after the wrapped session.
- Installs a SessionStart self-heal hook; `headroom unwrap claude` is the cleanup path.
- Registers Headroom MCP unless `--no-mcp` is supplied.
- May install/configure code-memory support; `--memory` adds `.headroom/memory.db` and instruction guidance.

Because the current repository already has curated agent instructions and MCP/memory infrastructure, avoid the Claude wrapper for the first test. A manually scoped proxy changes no agent configuration.

### Direct MCP installation

`headroom mcp install` detects supported agents and can modify both Claude and Codex configuration unless restricted with `--agent`. For Codex it writes marker-bounded blocks to `$CODEX_HOME/config.toml`; for Claude it uses the user-scope MCP configuration. The Codex registrar refuses to overwrite an existing user-managed server with the same name. [MCP installation and lifecycle](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/docs/content/docs/mcp.mdx#L102-L177)

Do not install this MCP initially. Proxy compression is automatic, while explicit MCP calls add tools and can consume additional context. Headroom itself recommends the proxy for automatic normal traffic. [MCP trade-offs](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/docs/content/docs/mcp.mdx#L206-L235)

## Telemetry, data, and security

- The proxy receives complete prompts, tool output, request headers, and provider credentials before forwarding a transformed request to the configured upstream. It is therefore a high-trust local dependency.
- Bind only to `127.0.0.1`. Headroom requires its proxy token only for non-loopback clients; a non-loopback bind without a token leaves `/v1` routes unauthenticated. [Proxy authentication behavior](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/headroom/proxy/server.py#L3080-L3139)
- Leave full message logging disabled. `--log-messages` stores request and response contents.
- Default MCP retrieval keeps originals locally for one hour and in the proxy for five minutes. [Retrieval storage](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/docs/content/docs/mcp.mdx#L42-L100)
- Current telemetry is fail-closed: only an explicit `HEADROOM_TELEMETRY=on` enables local aggregate collection, and the former anonymous beacon no longer sends data to Headroom Labs. [Telemetry implementation](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/headroom/telemetry/beacon.py#L1-L36)
- Managed licensing is different: setting `HEADROOM_LICENSE_KEY` enables license/aggregate-usage reporting to Headroom's license API. It is documented in source as excluding prompts, API keys, tool results, and user data, but it is still external reporting. [Managed usage reporter](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/headroom/telemetry/reporter.py#L1-L18)
- There is a configuration inconsistency: current docs and normal `proxy`/`wrap`/`deploy` paths say telemetry defaults off, while the legacy `headroom init` path generates manifests with telemetry enabled. Avoid `headroom init` and set `HEADROOM_TELEMETRY=off` explicitly. [Legacy init behavior](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/headroom/cli/init.py#L549-L617)

Do not set `HEADROOM_KOMPRESS_ENDPOINT`, OpenTelemetry export variables, or a license key during the local pilot. Keep TLS verification strict.

## Current release risks

The open reports below are user reports, not independently reproduced findings, but they make a global rollout premature:

- [Codex WebSocket compression worker hangs after timeout](https://github.com/headroomlabs-ai/headroom/issues/2360)
- [Codex WebSocket 403 with project-prefixed routing](https://github.com/headroomlabs-ai/headroom/issues/2355)
- [Codex Desktop stream disconnect](https://github.com/headroomlabs-ai/headroom/issues/1944)
- [Codex Desktop history/context loss](https://github.com/headroomlabs-ai/headroom/issues/1788)
- [Claude completed responses discarded and duplicate paid calls](https://github.com/headroomlabs-ai/headroom/issues/2340)
- [Claude signed extended-thinking blocks corrupted by serialization](https://github.com/headroomlabs-ai/headroom/issues/2251)

Pin `v0.32.0`; do not install from untagged `main`. Re-evaluate after the next release includes the post-`v0.32.0` Codex wrapper fixes.

## Minimal adoption plan

### 1. Install a pinned proxy-only footprint

Headroom recommends `uv tool` and Python 3.13. The `proxy` extra includes both proxy and MCP runtime dependencies, but installing it does not itself register MCP servers. [Installation options](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/docs/content/docs/installation.mdx#L16-L109)

```sh
uv tool install --python 3.13 'headroom-ai[proxy]==0.32.0'
```

### 2. Pilot Claude Code CLI without wrapper mutations

Terminal 1:

```sh
HEADROOM_TELEMETRY=off headroom proxy --host 127.0.0.1 --port 8787
```

The tracked `claude()` shell wrapper explicitly unsets `ANTHROPIC_BASE_URL`.
Do not replace it or bypass its rbw/OTEL behavior. Add a separate canary launcher
next to it that preserves the existing `_rbw_env` and `_omni_otel_run` sequence,
but exports these two values before launching the real Claude binary:

```sh
ENABLE_TOOL_SEARCH=true
ANTHROPIC_BASE_URL=http://127.0.0.1:8787
```

Do not use this environment for Claude Remote Control or the VS Code extension.

### 3. Hold Codex App; optionally run a disposable Codex CLI test

For `v0.32.0`, the least-mutating supported wrapper invocation is:

```sh
HEADROOM_TELEMETRY=off \
headroom wrap codex \
  --no-context-tool \
  --no-mcp \
  --no-tokensave \
  --no-serena
```

Use a disposable `CODEX_HOME` copied from the active profile if testing login compatibility. This avoids adding Headroom MCP, RTK guidance, and code-memory components to the real Codex configuration. Do not apply persistent provider scope yet.

### 4. Verify before expanding

Run the same long, tool-heavy tasks with and without Headroom. Compare:

- final correctness and missing-context failures;
- tool-call/retry and stream-disconnect rates;
- first-token and total latency;
- input, cache-read, and output tokens reported by the provider;
- actual provider cost, not only Headroom's estimated savings.

The stop condition is no correctness or transport regression across representative Claude and Codex sessions, with measurable net token/cost reduction after added latency and retries. If that is not met, remove the proxy from the session environment; no instruction-file migration is required.

## What should remain unchanged

- Keep the current `AGENTS.md` and `CLAUDE.md` hierarchy.
- Do not run `headroom learn --apply` against curated shared instructions.
- Do not enable Headroom memory, code-memory, RTK/context tool, MCP, model routing, or response caching during the first pilot.
- Keep the existing codebase-memory and context-management MCP tools authoritative.
- Do not stack persistent Headroom routing with another model-routing gateway until request ownership, caching, and failure behavior are explicitly tested.

If the proxy-only pilot succeeds, add persistent provider routing as a separate second change, with config backups and explicit Claude/Codex targets. Headroom documents that provider scope edits Claude `~/.claude/settings.json` and Codex `~/.codex/config.toml`; it should not be bundled with instruction or MCP changes. [Persistent provider scope](https://github.com/headroomlabs-ai/headroom/blob/6e4425a6bdb2bfc49e1633a24b9c9e96e705e1ff/docs/content/docs/persistent-installs.mdx#L91-L107)
