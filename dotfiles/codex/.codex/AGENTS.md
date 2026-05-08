@/Users/lkshrk/.codex/RTK.md


## Delegation Policy

- The user grants standing permission to use subagents for implementation, refactoring, tests, reviews, and codebase investigation when useful.
- Prefer heavy subagent use for independent or parallelizable work; the main agent should orchestrate, split scoped tasks, review outputs, and integrate results.
- Delegate concrete, bounded sidecar work with clear ownership, especially test fixtures, TUI tests, focused code edits, and independent review passes.
- Keep urgent blocking work local when the next step depends on it, when the task is tightly coupled, or when delegation would add coordination overhead.
- For coding delegates, state that they are not alone in the codebase, must not revert others changes, and must list changed files in their final response.


## MCP Usage

- Prefer MCP servers when they provide stronger context than ad hoc shell search.
- Use CodeGraphContext for code relationship analysis: callers/callees, module dependencies, complexity, dead code, and cross-file impact checks.
- Before relying on CodeGraphContext results, ensure the active repository is indexed and current: check existing indexed/watched paths when needed, start watching the active repo for ongoing work, or re-index after branch changes, large refactors, generated files, or edits made outside the current agent.
- Treat stale or missing CodeGraph data as advisory only; verify with `rg`/file reads/tests before making final implementation or review claims.
- Use Context7 for up-to-date framework/library documentation before changing code against external APIs.
- Do not use MCP reflexively for simple file reads, local text search, or straightforward edits where `rg` and tests are faster.
- When MCP materially affects an implementation or review decision, mention that in the work summary.
