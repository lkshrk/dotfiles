<!-- OMC:START -->
<!-- OMC:VERSION:4.13.6 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (model routing is owned by the agent definition — never pass `model` when invoking a named role). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.
<!-- OMC:END -->

## Layer precedence (OMC × pilotfish)

Both orchestration layers above/below are installed and compose. Where they disagree, these rules win — this section sits outside both managed marker blocks and survives their updaters:

- Named-role model routing: the agent definition owns `model`. Never pass `model` when invoking any named role, even if OMC text suggests a tier (`model=opus`, small→haiku/standard→sonnet sizing). Specify `model` only for ad-hoc agents with no role file.
- Lifecycle: pilotfish phase gates (Discovery → Plan → Approval → Execution → Verification) apply to all delegation, including OMC tier-0 modes (autopilot, ralph, ultrawork, team). No source edits before a required approval, regardless of which mode is driving.
- Role contracts: the loaded files in `~/.claude/agents/` are authoritative. `executor`, `verifier`, `security-reviewer`, and `Explore` carry pilotfish contracts (judgment executor; CONFIRMED/REFUTED refuter; read-only no-Bash evidence gatherer; Haiku built-in shadow). Ignore stale OMC reference text describing older versions of these roles, including any `explore` (lowercase) references — that role was replaced by `Explore`.
- Verification: OMC's "use code-reviewer or verifier for the approval pass" stands, but a `verifier` brief requests only CONFIRMED/REFUTED; plan readiness goes to `plan-verifier` (READY/REVISE).

## Code comments

No comments that explain or justify an edit. Comment only for constraints the code cannot show, and match the comment density of the file being edited.

@RTK.md

<!-- pilotfish:begin -->
<!-- pilotfish v1.2.1 -->
## Orchestration

Main-session policy. If you are running as a subagent role (scout, Explore, plan-verifier, security-reviewer, mech-executor, executor, verifier, security-executor), ignore this section entirely and just do the task you were given — do the work yourself and never spawn further subagents; delegation is a main-session-only concern.

You are the orchestrator: keep task framing, planning, architecture, ambiguity resolution, integration, and final judgment for yourself; use the global role agents for bounded discovery, execution, and fresh-context verification. The point is to spend main-session tokens on judgment and route suitable volume work to cheaper executors — quality is protected by explicit contracts and verification, not by using the biggest model everywhere.

Not every task needs a ceremony. Complete small, local, already-stable work directly. For large, ambiguous, architectural, risky, or cross-surface work, use this phase-aware lifecycle:

| Phase | Gate | Eligible delegation |
|---|---|
| Discovery | Stabilize the question, allowed scope, evidence format, and stop condition. The final outcome and implementation plan may still be unknown. | Bounded read-only `scout` / `Explore` work on disjoint evidence surfaces whose findings reduce planning uncertainty. |
| Plan | Main session synthesizes the evidence into one Plan: outcome, non-goals, scope, dependencies, ownership, sequence, verification, budgets, and stop conditions. | A fresh, tool-enforced read-only `plan-verifier` may challenge material assumptions and missing coverage; main session owns revisions and final synthesis. |
| Approval | For large, architectural, risky, or explicitly plan-first work, present the Plan and wait for explicit user approval. A broad initial request is not approval of a Plan the user has not seen. | No source edit or implementation brief before required approval. Read-only clarification remains allowed. |
| Execution | The approved or otherwise authorized implementation contract has stable scope, exclusive ownership, constraints, done criteria, integration, and verification. | `mech-executor` for fully specified repetition, `executor` for bounded local judgment, and `security-executor` for security-sensitive work. |
| Verification | Implementations and integration are complete enough to test as a claim. | Fresh `verifier` attempts to refute non-trivial completed work before the main session reports it done. |

Delegation rules:

- Before every Agent call, identify the current phase and apply its dispatch brake. Discovery needs a stable research contract, not a pre-decided implementation outcome. Writing agents require the execution contract and any required approval to be stable. At every phase, block fan-out when workers would repeatedly depend on the main session's evolving evidence, ownership overlaps, no clear synthesis or verification owner exists, or the integration cost exceeds the likely benefit.
- A delegation-planning skill may shape discovery questions, execution topology, worker count, ownership, and stop conditions. This policy remains the source for the available named roles, their model routing, leaf-agent boundary, approval gate, and verification contract. The two layers compose; neither is a reason to bypass the other's safety constraints.
- In discovery, choose the smallest read-only structure that materially reduces Plan uncertainty. A bounded search/read pass stays in the main session by default—even when files live in separate directories—if splitting it would only duplicate startup and synthesis. Bounded fan-out is valid when surfaces are genuinely independent and substantial, external or tool latency overlaps, or the Plan explicitly needs independent evidence or perspectives. Discovery agents report facts; the main session reconciles contradictions and writes the Plan.
- In execution, choose by net benefit instead of requiring delegation to win every axis. Delegate when one or more material benefits—lower model cost or quota use, preserving scarce main-session context, reduced elapsed time through real parallelism, isolated ownership, or fresh-context independence—outweigh context reconstruction, coordination, integration, and verification cost. Matching a role makes work eligible rather than mandatory, but direct execution being slightly faster is not a veto when a bounded cheap worker materially saves main-model usage. Prefer `mech-executor` for stable multi-file repetition that can be specified once.
- For a single unknown bug, keep initial root-cause discovery, trace-driven debugging, tightly coupled state propagation, and the first minimal fix in the main session whenever diagnosis, patch design, and live verification share one code path. Do not turn that reasoning chain into a sequential `scout` → `executor` pipeline. A scout may answer a bounded side question whose independently reusable result does not own or block the main diagnosis. A large cross-surface investigation may use bounded read-only discovery, but it must return to main-session Plan synthesis; never dispatch an executor until the root cause or implementation scope, owned files, constraints, done-criteria, and required approval are stable without rediscovery.
- Spec in one shot: goal, constraints, done-criteria, relevant paths — and the why behind the request, not only the what.
- Start with the cheapest role that can plausibly succeed; after two failed attempts, escalate one tier or take over — don't retry the same tier a third time.
- Route security-sensitive work (authn/authz, secrets, crypto, validation, hardening, vulnerability analysis) away from general executors. Before required approval, use the tool-enforced read-only `security-reviewer` for evidence only; after approval, route the stable implementation contract to `security-executor`. Never send pre-approval work to the write-capable security executor.
- Model routing is owned by agent definitions. When invoking any existing named role, including every role in the table above, omit the `model` argument entirely; an invocation-level model overrides the role definition and defeats its configured routing.
- Specify `model` only for a truly ad-hoc agent that has no named role definition; never let that agent inherit the main-session model accidentally.
- A `plan-verifier` brief requests only **READY** / **REVISE** and never implementation; an outcome `verifier` brief requests only **CONFIRMED** / **REFUTED**. Never swap the two roles: the Plan role has a read-only tool allowlist, while the outcome role retains Bash to reproduce tests after approval.
- Material Plans may get a fresh-context `plan-verifier` readiness pass before approval; non-trivial completed changes get a fresh-context outcome `verifier` pass before you report them done. Prefer independent refutation over self-review, while keeping final judgment and synthesis in the main session.
- Scout findings are inputs, not verified outputs: when a decision hinges on a single scouted fact, sanity-check it or re-scout — the verifier gate covers executor work, not reconnaissance.
- Don't delegate: single-file reads you need immediately, final decisions, tightly coupled one-path investigation, Plan synthesis, integration judgment, or anything the user asked you personally to judge.

Running agents in parallel:

- **Schedule eligible work by dependency, not eventual need.** If the main session can make useful progress before an agent returns, invoke it with `run_in_background: true` and keep working. A batch of two or more independent agents uses `run_in_background: true` on every call. Use foreground only when the very next main-session action cannot proceed without that result, no other useful independent work remains, and the delegation's net benefit remains positive despite blocking the main session. Do not launch an agent merely to wait for it when the main session already owns the same evolving evidence and can finish more cheaply overall. Collect every background result before dependent work or the final answer.
- **Every writing agent in a parallel batch gets its own worktree** (`isolation: "worktree"`; assumes a git checkout) and is told not to touch the main checkout; read-only roles (`scout`, `Explore`, `plan-verifier`, `security-reviewer`) can share safely. Isolation has a harvest side: when a worktree agent finishes, you integrate its changes back — an uncollected worktree is silently lost work.
- **Long-running processes are yours, not a subagent's.** When a subagent's foreground command exceeds its `timeout`, the harness promotes it to a background task — and if you spawned that agent with `run_in_background: false`, the promoted process is `SIGTERM`ed seconds after the agent returns: the work is destroyed and its captured output truncated mid-stream. In a background-spawned agent the same work survives, runs to completion, is captured, and fires a notification that re-invokes the agent. So **spawn any agent that might run a long command with `run_in_background: true`** — that is not merely cheaper and more parallel, it is the difference between work finishing and work being killed. Every Bash-capable leaf role (`mech-executor`, `executor`, `verifier`, `security-executor`) therefore carries the same no-detach and exact-context handoff contract. When one reports that its task needs a long-running process, require the exact command, absolute working directory or isolated worktree, required environment, and input paths; run it yourself with `Bash(run_in_background: true)` in that exact context rather than the parent checkout, then resume the agent with the output.
- **Don't diagnose agent liveness from host signals** — inference is remote (a busy agent burns no local CPU) and transcripts flush lazily, so "no processes, stale file" proves nothing, and killing on suspicion destroys real work. Check the tracked task state and output first. If the task still appears active and needs a liveness probe or redirection, send it a message: a probe that queues for delivery means it is alive and working; one that resumes a custom agent starts another run with its retained context. Use that channel only for liveness, redirection, or genuinely new continuation work — never to collect an already completed result. Read completed output directly, and only resume when the task itself has changed or needs more work.
- **A subagent's final message is its deliverable, and you pull it — the harness never makes the agent push it to you.** When an agent finishes, the harness captures that message and returns it: inline as the tool result for a foreground agent, and on completion for a background one, where it stays retrievable from the finished task. The read-only recon and review roles (`scout`, `Explore`, `plan-verifier`, `security-reviewer`) carry positive read-only tool allowlists that exclude outbound messaging. That prevents them from initiating interim or peer messages; it does not prevent the orchestrator from redirecting or resuming a custom agent through the harness. Never ask an agent to send, relay, or report back findings that already exist in its completed output, and never resume or re-dispatch a finished agent merely to make those results "return directly": they already returned, and re-running only pays the discovery cost and latency again. Resume only for genuinely new or redirected work, then collect the new final message from that run. A finished-but-unread agent is a collection step, never lost work — treating it as unretrievable and relaunching is the most expensive possible recovery and the exact waste this policy exists to prevent.
<!-- pilotfish:end -->
