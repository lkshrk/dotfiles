# LiteLLM proxy review

Reviewed 2026-07-18 against `h-cloud` commit `2efa1aea9945ba8fed522a97c9cf9e26d0d25719` and live cluster state.

## Verdict

The proxy foundation is solid: LiteLLM `v1.91.2` is exactly pinned, PostgreSQL and SSO are configured, health probes pass, OpenTelemetry is active, and Redis response caching is connected and working. The largest missed benefit is simpler: Codex and Claude model requests are not actually routed through LiteLLM. They only use its MCP endpoint.

Priority order:

1. Fix the database migration hook under Flux.
2. Route Codex and Claude model traffic through separate LiteLLM virtual keys.
3. Make caching conservative and measurable for coding traffic.
4. Reduce retry amplification and repair fallback permissions.
5. Harden local OAuth-file permissions and prompt logging.

## Verified current state

- [LiteLLM Helm values](/Users/lkshrk/Dev/h-cloud/kubernetes/apps/ai/litellm-proxy/app/helmrelease.yaml) use one ready pod, a 600-second request timeout, Redis DB 4, namespace `litellm-cache`, TTL 3600 seconds, three retries, and 60-second cooldowns.
- Live `/cache/ping` reports Redis 7.2.4 healthy, successful set/get behavior, namespace `litellm-cache`, TTL 3600, and cache mode `default_on`.
- Live readiness reports LiteLLM `1.91.2`, database connected, Redis cache connected, OpenTelemetry callbacks active, and detailed debug logging disabled.
- [Model aliases](/Users/lkshrk/Dev/h-cloud/kubernetes/apps/ai/litellm-proxy/app/resources/model-list.yaml) expose 14 aliases across OpenRouter and CLIProxyAPI.
- [Codex config](/Users/lkshrk/Dev/dotfiles/dotfiles/codex/.codex/config.toml:13) still uses the native OpenAI provider. LiteLLM appears only as an MCP server.
- [Claude/Codex wrappers](/Users/lkshrk/Dev/dotfiles/dotfiles/zsh/.config/zsh/macos/75-secret-wrappers.zsh:21) explicitly clear Claude proxy variables and inject only a shared `LITELLM_API` key for MCP.
- Claude enables `FORCE_PROMPT_CACHING_5M=1`. That controls provider prompt caching; it is separate from LiteLLM's exact response cache.

## P0 — repair database migrations

The running pod logs `prisma schema out of sync with db` and lists missing MCP-related columns, tables, and indexes. `DISABLE_SCHEMA_UPDATE=true` is appropriate only when the separate migration job reliably runs.

The chart defaults its migration job to an Argo CD `PreSync` hook. Flux does not execute that as a Helm hook, and neither the installed release manifest nor the namespace contains the expected migration Job. Configure the chart for Helm hooks:

```yaml
migrationJob:
  hooks:
    argocd:
      enabled: false
    helm:
      enabled: true
```

Then reconcile and verify:

- the migration Job is created and succeeds;
- a restarted proxy no longer logs schema drift;
- readiness and one authenticated model request still pass.

Do this before upgrading LiteLLM. LiteLLM's production guidance explicitly recommends controlled schema migrations and separate migration execution: [production best practices](https://docs.litellm.ai/docs/proxy/prod).

## P1 — route the CLIs through LiteLLM

### Codex

Current Codex supports custom model providers with a base URL, environment-backed key, and Responses wire protocol. Add a provider equivalent to:

```toml
model = "gpt-5.6-sol"
model_provider = "litellm"

[model_providers.litellm]
name = "LiteLLM"
base_url = "https://api.ai.h-cloud.lan/v1"
wire_api = "responses"
env_key = "LITELLM_API"
```

Source: [Codex advanced configuration](https://learn.chatgpt.com/docs/config-file/config-advanced).

### Claude Code

Claude Code's documented gateway configuration is:

```sh
ANTHROPIC_BASE_URL=https://api.ai.h-cloud.lan
ANTHROPIC_AUTH_TOKEN=<dedicated-litellm-virtual-key>
```

The current wrapper unsets both variables, so model traffic bypasses LiteLLM. Use `ANTHROPIC_AUTH_TOKEN`, not a helper that also emits `X-Api-Key`, because `forward_client_headers_to_llm_api: true` forwards `x-*` headers upstream. Source: [Claude Code LLM gateway](https://docs.anthropic.com/en/docs/claude-code/llm-gateway).

### Separate keys

Do not reuse one `LITELLM_API` key for Codex, Claude, and MCP. Create three virtual keys with distinct aliases, model allowlists, budgets, RPM/TPM limits, and maximum parallel requests. This gives useful attribution and prevents one client from exhausting every workload. See [virtual keys](https://docs.litellm.ai/docs/proxy/virtual_keys) and [budgets/rate limits](https://docs.litellm.ai/docs/proxy/users).

Before switching defaults, smoke-test `/v1/responses` with the Codex alias and the Anthropic-compatible route with tool use, streaming, and a long context.

## P1 — tune caching for coding traffic

### What is already good

- Dedicated Redis DB and namespace avoid collisions.
- A finite TTL is required because the shared Valkey uses an eviction policy.
- The live cache health check proves connectivity and writeability.

### Recommended policy

Provider prompt caching is usually the valuable layer for coding agents: long, repeated system prompts, tool definitions, and stable conversation prefixes can be reused while the latest user turn changes. Verify savings using provider usage fields such as `cache_read_input_tokens`, `cache_creation_input_tokens`, or `prompt_tokens_details.cached_tokens`. See [LiteLLM prompt caching](https://docs.litellm.ai/docs/completion/prompt_caching).

Exact response caching has lower expected hit rate and higher staleness risk for repository state, tool output, and conversational requests. Prefer:

```yaml
litellm_settings:
  cache: true
  enable_caching_on_provider_specific_optional_params: true
  cache_params:
    type: redis
    host: valkey.valkey.svc.cluster.local
    port: 6379
    db: 4
    namespace: litellm-cache
    ttl: 3600
    mode: default_off
```

Opt in only for deterministic, read-only requests such as repeated documentation questions or evaluations. If the CLIs cannot add the opt-in flag and global caching is retained, keep the short TTL, narrow `supported_call_types` to the actual chat/Responses methods, and monitor cache-hit rate before assuming savings. Respect `Cache-Control: no-cache` and `no-store` for freshness-sensitive requests. Details: [LiteLLM response caching](https://docs.litellm.ai/docs/proxy/caching).

Do not enable semantic caching globally for coding or tool traffic. Similar wording does not mean equivalent repository state, permissions, tool results, or required output.

## P1 — fix retries and fallbacks

`num_retries: 3` targets a single deployment for most model groups. It can repeat the same upstream failure, multiply latency and token spend, and then cool down the only deployment for 60 seconds. Start with one retry, or two maximum for transient transport/rate-limit failures. Add deployment-level cooldowns only where a group has genuine redundant deployments or a tested general fallback. See [reliability and fallbacks](https://docs.litellm.ai/docs/proxy/reliability) and [routing](https://docs.litellm.ai/docs/routing).

The current context-window fallback is also permission-inconsistent:

- `claude-haiku` and `claude-sonnet-4` allow `standard` keys.
- Their fallback, `claude-sonnet-5`, allows only `premium` keys.

Oversized requests from standard keys can therefore fail at the fallback. Either permit a standard-accessible fallback or deliberately remove those mappings. Also validate tool schemas, streaming, context capacity, and cost before crossing providers or model families.

## P1 — privacy and local security

For coding traffic, add these settings unless raw prompt/body observability is explicitly required:

```yaml
litellm_settings:
  turn_off_message_logging: true
  redact_user_api_key_info: true
```

OpenTelemetry is already active, while Codex also exports user prompts. Confirm that prompts are not duplicated into multiple telemetry systems and that retention/access controls match the sensitivity of source code and secrets. See [logging](https://docs.litellm.ai/docs/proxy/logging) and [security best practices](https://docs.litellm.ai/docs/proxy/security_best_practices).

Locally, `~/.cli-proxy-api` is mode `0755` and OAuth credential JSON files are `0644`. They contain access, refresh, and identity tokens. Change the directory to `0700` and credential files to `0600`.

## P2 — upgrade and scale only when justified

- `v1.91.2` is one stable release behind `v1.92.0`. The newer release includes a relevant fix for replaying OpenAI Responses bridge cache hits as chat streams. Fix migrations first, then stage and validate the upgrade: [v1.92.0 release](https://github.com/BerriAI/litellm/releases/tag/v1.92.0), [release cycle](https://docs.litellm.ai/docs/proxy/release_cycle).
- One worker in one pod is sensible for a personal/internal installation. Scale horizontally only when concurrency or availability data requires it. When scaling beyond one proxy, keep shared Redis and size database connection pools per pod: [production best practices](https://docs.litellm.ai/docs/proxy/prod).
- OpenTelemetry already provides observability. Add Prometheus only if it answers operational questions not covered by existing telemetry: [Prometheus integration](https://docs.litellm.ai/docs/proxy/prometheus).

## Keep as-is

- Exact image/chart version pinning.
- SOPS-managed Kubernetes secrets and rbw-based local secret injection.
- Separate liveness and readiness probes.
- 600-second request timeout instead of LiteLLM's unusually long default.
- Dedicated Redis DB/namespace and a finite cache TTL.
- Detailed debug logging disabled.
- `service_callback` singular for installed `v1.91.2`; do not change it to a moving-documentation variant until an upgrade test proves compatibility.

## Completion checklist

- [ ] Migration Job runs under Flux; schema-drift warning disappears.
- [ ] Dedicated Codex, Claude, and MCP virtual keys exist with model/rate/budget scopes.
- [ ] Codex streaming Responses request succeeds through LiteLLM.
- [ ] Claude streaming/tool-use request succeeds through LiteLLM.
- [ ] Provider cached-token counters show whether prompt caching is effective.
- [ ] Exact-cache hit rate and stale-response risk are measured; semantic cache remains off.
- [ ] Retry count and fallback access are corrected and failure-tested.
- [ ] Prompt/body logging and telemetry retention are reviewed.
- [ ] Local CLIProxyAPI credential directory/files use `0700`/`0600`.
- [ ] LiteLLM `v1.92.0` upgrade is tested only after migrations are healthy.
