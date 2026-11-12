# env

Shell-neutral environment layout for exported env, PATH, and secret injection.

`claude` and `cc` both launch Claude Code through LiteLLM, using the gateway
credential from `ENV/local-agents`. Override the endpoint with `LITELLM_BASE_URL`.
Claude uses the system certificate trust without a per-launch CA wrapper; other
AI clients retain the shared CA helper in `65-ai-certs.zsh` (`OMNI_CA_PATH`).

Codex uses the LiteLLM Responses provider with its existing Astra default.
Its native token command calls `bin/local-agents-token`: an injected
`LITELLM_API_KEY`, a private token file, or the vault gateway item.

`omp` uses `~/.local/bin/omp` → `bin/omp-local-agents` to inject the same
`ENV/local-agents` credential as `LITELLM_API_KEY` into the OMP process.
`~/.omp/agent/models.yml` discovers LiteLLM models under `local-agents`:
Claude uses Anthropic Messages, GPT uses OpenAI Responses, and other chat
models use OpenAI Chat Completions. The default is `local-agents/gpt-astra`.
For example: `omp --model local-agents/claude-opus`.

OMP's local essentials live in `~/.omp/agent/config.yml`, separately from
provider definitions in `models.yml`: `default` uses `local-agents/gpt-astra`,
`smol` uses `local-agents/claude-sonnet:low`, and `slow` uses
`local-agents/claude-opus:high`. `plan` follows `@slow`, `task` follows
`@default`, and `commit` follows `@smol`. Bundled agent definitions remain
unchanged; shared skills load from `~/.agents/skills`.
Their Omni-managed sources and invocation syntax are documented under
[Agent skills](../../../../README.md#agent-skills).

APM generates the untracked `~/.omp/agent/mcp.json` from the tracked
`apm/ai-plugins/apm.yml` declarations. It launches the pinned `context-mode`
plugin copy and the `litellm-tools` HTTP gateway, preserving both entries'
`instructions: false`. The gateway exposes Linear, Context7, and SearXNG;
Context Mode remains local for large-output processing. OMP resolves the
`x-litellm-api-key` header at connection time by running
`~/.config/env/bin/litellm-mcp-headers` and extracting that JSON field with
`jq -er`. This reuses the existing `LITELLM_API`/rbw credential without
storing it in OMP configuration; it is separate from `LITELLM_API_KEY`.

`~/.omp/agent/AGENTS.md` supplies tool-routing and credential-handling
guidance. Other clients' MCP configurations are not imported wholesale.
Run `/mcp reload` in an existing session after changing MCP configuration;
start a new session to load changed user instructions. Omni's `omp` dots entry
allowlists only `config.yml`, `models.yml`, and `AGENTS.md` under
`~/.omp/agent`. Declaring the entry does not adopt or sync those files.
MCP remains APM-owned; generated hooks/extensions, credentials, sessions and
runtime databases are excluded from dotfile tracking.

The `omp` dots entry declares `config.yml`, `models.yml`, and `AGENTS.md` only.
It remains local-only until an explicit dots adoption/sync action; it never
tracks APM-generated MCP, extension, hook, credential, session, or database
state.

`opencode` and `oc` use `~/.local/bin/opencode` → `bin/opencode-local-agents`,
which injects the same credential as `LITELLM_API_KEY` and executes
`/usr/bin/opencode` (override with `OPENCODE_BIN`). There is no subscription
escape hatch: OpenCode holds no subscription credentials here, and the tracked
config allows only the `local-agents` provider.

OpenCode merges every global config document instead of replacing one with
another. APM owns `~/.config/opencode/opencode.json` (MCP only, currently
`context-mode`); dots own `opencode.jsonc` and `instructions/gateway-tools.md`.
`opencode.jsonc` declares `local-agents` against `https://api.ai.h-cloud.lan/v1`:
Claude models use `@opencode/ai/providers/anthropic`, GPT models
`openai/responses`, and the rest `openai-compatible` chat. The default is
`local-agents/claude-sonnet-high#high` and session titles use
`local-agents/claude-sonnet`, matching omp's `config.yml`. A `policies` block
denies every other provider. Add a model by declaring it under `models` with
its limits; OpenCode does not discover gateway models.

APM's OpenCode adapter drops `headersHelper`, so `litellm-tools` is excluded
from the `opencode` APM target. `opencode.jsonc` declares it instead, with
`x-litellm-api-key: {env:LITELLM_API_KEY}`. Global instructions come from
`instructions/gateway-tools.md` plus the shared
`~/.claude/rules/h-cloud-kubectl.md`; no `AGENTS.md` is tracked, so APM can
still generate one.

OpenCode v2 runs one background service that every client attaches to, and it
inherits the environment of whichever client starts it. Credentials resolve in
that service, so a service started outside the wrapper (or before the wrapper
existed) fails gateway authentication. Restart it from a wrapped shell with
`opencode service stop && opencode service start`, or pass `--standalone` for
a private server.

This is a Stow-shaped package: `dotfiles/env/.config/env` is managed as
`~/.config/env` by Omni/Stow.

## Layers

- `profile.sh`: POSIX-safe entrypoint for exported base env and PATH.
- `lib/path.sh`: POSIX-safe path helpers.
- `lib/dev-cache.sh`: points package-manager and build-tool caches (Go, npm,
  pnpm, Bun, Deno, uv, pip, Poetry and its virtualenvs, golangci-lint,
  Playwright, Helm, CPM.cmake, ccache, sccache) at `DEV_CACHE_HOME`
  (`~/.cache/dev`). On Linux that directory is its own Btrfs subvolume
  (`btrfs subvolume create ~/.cache/dev`), so no snapshot includes it.
  `~/.cargo` is a symlink to `~/.cache/dev/cargo`, because Omni and `.profile`
  hardcode that path. Cargo's `build-dir` puts intermediates in
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
- `tests/smoke.sh`: shell-mode checks before migration.
- `tests/linux-smoke.sh`: clean Linux env checks with fake HOME/NVM and
  optional rbw socket coverage.
- `tests/local-agents-wrappers-smoke.sh`: omp/OpenCode credential injection,
  `oc`, and the tracked OpenCode provider/MCP config.

## Stow/Omni Package Shape

- `zsh`: generic interactive zsh modules.
- `zsh/.config/zsh/macos/`: macOS-only interactive modules (Homebrew-backed
  lazy tool loaders and functions), sourced by `.zshrc` only on darwin.
- `zshenv` sources `profile.sh` directly (covers every zsh shell, login
  included). `zprofile` carries only login-only behavior, if any.

## Current Decisions

- No explicit npm path.
- zsh loads the same POSIX profile from `.zshenv`; login shells skip duplicate
  profile work through the profile load guard.
- Base env prepends the NVM default Node bin directory, so `#!/usr/bin/env node`
  CLIs work after Homebrew Node is unlinked.
- Interactive zsh auto-switches `.nvmrc` through the lightweight resolver and
  only loads full NVM when the fast installed-version path cannot resolve.
- No Corepack wrapper. NVM's `default-packages` installs `pnpm@11` into each
  new Node version.
- `pnpm` resolves from the active NVM Node bin directory; `PNPM_HOME/bin`
  holds pnpm-installed global commands.
- `NVM_DIR` is metadata only; loading nvm stays out of base env.
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
