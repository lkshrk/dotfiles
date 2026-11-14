# env

Shell-neutral environment layout for exported env, PATH, and secret injection.

## Agent launcher

Every AI agent CLI starts through `bin/agent-run <client>`:

| Command | Client | Secret profile | Notes |
|---|---|---|---|
| `claude`, `cc` | `claude` | `secrets/claude.envmap` | Claude Code through LiteLLM |
| `claude_hass`, `cc-hass` | `claude-hass` | `secrets/claude-hass.envmap` | Home Assistant gateway key |
| `claude_sub`, `ccs` | `claude-sub` | `secrets/claude-sub.envmap` | Anthropic subscription, no gateway |
| `codex` | `codex` | `secrets/codex.envmap` | |
| `omp` | `omp` | `secrets/omp.envmap` | via `~/.local/bin/omp` |
| `opencode`, `oc` | `opencode` | `secrets/opencode.envmap` | via `~/.local/bin/opencode` |

For each launch `agent-run`:

1. points the Claude clients at `LITELLM_BASE_URL` (default
   `https://api.ai.h-cloud.lan`); `claude-sub` clears every gateway variable;
2. sets `NODE_EXTRA_CA_CERTS` to the LAN CA when one is readable
   (`LAN_CA_PATH` first) and the caller has not set it;
3. loads the client's envmap through `rbw-env`; a secret rbw cannot provide is
   skipped, not fatal. Variables already set in the caller win;
4. without `LITELLM_API`, falls back to `bin/local-agents-token` (an injected
   `LITELLM_API_KEY`, the private token file, or the vault item), and exports
   the key as both `LITELLM_API` and `LITELLM_API_KEY`;
5. refuses to start Claude without `ANTHROPIC_AUTH_TOKEN`, or omp and OpenCode
   without the gateway key;
6. runs the first `<client>` binary on `PATH` that is not `agent-run` itself
   (override with `CLAUDE_BIN`, `CODEX_BIN`, `OMP_BIN`, `OPENCODE_BIN`).

`claude` and `codex` are shell functions (`functions/agents`, loaded by
`profile.sh`) because Claude's own installer owns `~/.local/bin/claude`. omp
and OpenCode are reached through symlinks, so launches outside zsh get their
secrets too:

```sh
ln -sf ~/.config/env/bin/agent-run ~/.local/bin/omp
ln -sf ~/.config/env/bin/agent-run ~/.local/bin/opencode
```

Add a client by giving it a `describe`/`prepare` entry in `bin/agent-run` and
a `secrets/<client>.envmap`. After changing an envmap, restart the client's
background service, which keeps the environment it started with:
`agent-run codex app-server daemon restart` for Codex; OpenCode's service is
described below.

Codex uses the LiteLLM Responses provider with its existing Astra default.
Its native token command calls `bin/local-agents-token`.

`~/.omp/agent/models.yml` discovers LiteLLM models under `local-agents`:
Claude uses Anthropic Messages, GPT uses OpenAI Responses, and other chat
models use OpenAI Chat Completions; the Anthropic overrides are generated from
`home/.chezmoidata/models.yaml`. For example:
`omp --model local-agents/anthropic/claude-opus`.

OMP's local essentials live in `~/.omp/agent/config.yml`, separately from
provider definitions in `models.yml`: `default` uses
`local-agents/anthropic/claude-sonnet:high` and `slow` uses
`local-agents/anthropic/claude-opus:high`. `plan` follows `@slow`, `task` follows
`@default`, and `commit` follows `@smol`. Bundled agent definitions remain
unchanged; shared skills load from `~/.agents/skills`.
Their sources (APM) and invocation syntax are documented under
[Agent skills](../../../../README.md#agent-skills).

APM generates the untracked `~/.omp/agent/mcp.json` from the tracked
`apm/ai-plugins/apm.yml` declarations. It writes the `litellm-tools` HTTP
gateway with `instructions: false`. The gateway exposes Linear, Context7, and
SearXNG. Every client gets the `x-litellm-api-key` header as the reference
`${LITELLM_API}`, never the value: `agent-run` supplies it from the client's
envmap in `secrets/`.

`~/.omp/agent/AGENTS.md` supplies tool-routing and credential-handling
guidance. Other clients' MCP configurations are not imported wholesale.
Run `/mcp reload` in an existing session after changing MCP configuration;
start a new session to load changed user instructions. chezmoi manages only
`config.yml`, `models.yml`, and `AGENTS.md` under `~/.omp/agent`.
MCP remains APM-owned; generated hooks/extensions, credentials, sessions and
runtime databases are excluded from dotfile tracking.

The `omp` dots entry declares `config.yml`, `models.yml`, and `AGENTS.md` only.
It remains local-only until an explicit dots adoption/sync action; it never
tracks APM-generated MCP, extension, hook, credential, session, or database
state.

OpenCode has no subscription escape hatch: OpenCode holds no subscription credentials here, and the tracked
config allows only the `local-agents` provider.

OpenCode merges every global config document instead of replacing one with
another. APM owns `~/.config/opencode/opencode.json` (MCP only, currently
`context-mode`); dots own `opencode.jsonc` and `instructions/gateway-tools.md`.
`opencode.jsonc` declares `local-agents` against `https://api.ai.h-cloud.lan/v1`:
Claude models use `@opencode/ai/providers/anthropic`, GPT models
`openai/responses`, and the rest `openai-compatible` chat. The default is
`local-agents/anthropic/claude-sonnet#high` and session titles use
`local-agents/anthropic/claude-sonnet`, matching omp's `config.yml`. A
`policies` block denies every other provider. OpenCode does not discover
gateway models: add one to `home/.chezmoidata/models.yaml` (gateway id, family
and the limits from LiteLLM's `/model/info`) and chezmoi renders it into
OpenCode, Zed and omp; `tests/gateway-models.sh` checks they agree.

APM's OpenCode adapter drops `headersHelper`, so `litellm-tools` is excluded
from the `opencode` APM target. `opencode.jsonc` declares it instead, with
`x-litellm-api-key: {env:LITELLM_API_KEY}`. Global instructions come from
`instructions/gateway-tools.md` plus the shared
`~/.claude/rules/h-cloud-kubectl.md`; no `AGENTS.md` is tracked, so APM can
still generate one.

OpenCode v2 runs one background service that every client attaches to, and it
inherits the environment of whichever client starts it. Credentials resolve in
that service, so a service started outside the wrapper (or before the wrapper
existed) fails gateway authentication. Restart it with
`opencode service stop && opencode service start` (the `opencode` symlink runs
both through `agent-run`), or pass `--standalone` for a private server.

chezmoi writes this directory from `home/dot_config/env` in the dotfiles repo
to `~/.config/env`. Its tests live in the repo's `tests/` and run against
`scripts/render-home.sh <host>` output, because the source uses chezmoi names
such as `executable_agent-run`.

## Layers

- `profile.sh`: POSIX-safe entrypoint for exported base env and PATH.
- `lib/path.sh`: POSIX-safe path helpers.
- `lib/dev-cache.sh`: points package-manager and build-tool caches (Go, npm,
  pnpm, Deno, uv, pip, Poetry and its virtualenvs, golangci-lint,
  Playwright, Helm, CPM.cmake, ccache, sccache) at `DEV_CACHE_HOME`
  (`~/.cache/dev`). On Linux that directory is its own Btrfs subvolume
  (`btrfs subvolume create ~/.cache/dev`), so no snapshot includes it.
  `~/.cargo` is a symlink to `~/.cache/dev/cargo`, because rustup expects
  that path. Cargo's `build-dir` puts intermediates in
  `~/.cargo/build/<workspace hash>`; `target/` keeps only final artifacts.
  On Linux, `/var/lib/docker` and `/var/lib/containerd` are mounted from the
  top-level subvolumes `@docker` and `@containerd` (`/etc/fstab`, like `@pkg`),
  so snapper snapshots and rollbacks of `@` leave them alone.
- `bin/dev-clean`: manual cleanup, dry run unless `--apply`. Clears tool caches
  with each tool's own command plus Docker build cache and unused images;
  removes git-ignored caches in repositories under `~/Dev`; in each Cargo
  build dir and `target/` keeps only the most recently built profile (newest
  `.fingerprint`, or for artifact-only `target/` dirs the newest profile
  directory), drops that profile's `incremental/`, and skips any profile whose
  lock a running build holds; `git worktree prune` runs only with `--apply`
  (a dry run lists what it would prune); removes clean,
  unlocked worktrees merged (or squash-merged) into the default branch, unless
  a process runs inside one or it has no commits and is under two days old.
  Branches are kept.
- `os/<name>.sh`: OS-specific env and PATH facts.
- `machine/<name>.sh`: machine-specific env and PATH facts.
- `bin/rbw-env`: shell-neutral secret injection wrapper for agents, zsh
  wrappers, and one-off commands.
- `bin/rbw-ssh-pubkeys`: writes fingerprint-named public-key selectors for
  rbw's native SSH agent to `~/.ssh/rbw`.
- `secrets/*.envmap`: rbw item to environment variable mappings by consumer.
  An item written as `<folder>/<name>` is fetched with `rbw get --folder`, for
  names that exist in more than one folder.
- `tests/env-smoke.sh`: shell-mode checks on macOS (runs `env-linux-smoke.sh`
  on Linux).
- `tests/env-linux-smoke.sh`: clean Linux env checks with a fake HOME and mise
  shims, and optional rbw socket coverage.
- `tests/agent-run-smoke.sh`: every agent client's profile, gateway fallback,
  isolation, CA and binary lookup, with a fake rbw.
- `tests/opencode-config-smoke.sh`: the tracked OpenCode provider/MCP config.

## Shell layout

- `~/.config/zsh` (`home/dot_config/zsh`): generic interactive zsh modules.
- `~/.config/zsh/macos/`: macOS-only interactive modules (Homebrew-backed
  lazy tool loaders and functions), sourced by `.zshrc` only on darwin.
- `zshenv` sources `profile.sh` directly (covers every zsh shell, login
  included); there is no `zprofile`.

## Current Decisions

- No explicit npm path.
- zsh loads the same POSIX profile from `.zshenv`; login shells skip duplicate
  profile work through the profile load guard.
- Base env puts mise's shims right after `~/.local/bin`, so node, npm, npx,
  pnpm and the other mise tools resolve without `mise activate`. On Omarchy,
  node comes from its own mise layer; on macOS from the darwin block of
  `mise/conf.d/node.toml`.
- A project's `.nvmrc` (or `.node-version`) picks its node version through mise
  (`idiomatic_version_file_enable_tools = ["node"]`); no nvm, no shell hook.
- No Corepack wrapper. pnpm comes from mise; `PNPM_HOME/bin` holds
  pnpm-installed global commands.
- Homebrew environment policy is macOS-specific. `os/darwin.sh` resolves and
  exports `HOMEBREW_PREFIX`; zsh lazy tool modules consume that variable
  instead of hardcoding Homebrew install paths.
- Homebrew OpenJDK is interactive-lazy through zsh wrappers; base env does not
  export `JAVA_HOME` or prepend Java bins.
- `KUBECONFIG` is machine-specific, not macOS-specific.
- `SSH_AUTH_SOCK` preserves existing agents by default. macOS points launchd
  shells at the rbw socket path; Linux adopts an existing rbw socket when one is
  present, otherwise points GUI sessions at `$XDG_RUNTIME_DIR/rbw/ssh-agent-socket`
  when rbw is installed and no agent is set.
- Maestro is project-local via direnv `.envrc`, not global env.
- `~/.cargo/bin` is on PATH.
- `~/.local/bin` wins over package-manager binaries.
- direnv hooks load in every interactive zsh (`zsh/35-direnv.zsh`), not base env.
- rbw secret injection is profile-based: `rbw-env <profile> -- <command>`.
