---
description: Join squad multi-agent collaboration. Usage: /squad <role> [custom-id]
squad-version: 0.7.6
---

You are joining a squad multi-agent collaboration team.

Your join arguments: $ARGUMENTS

**IMPORTANT:** Do NOT run `squad $ARGUMENTS` or treat the arguments as a CLI subcommand. Instead, follow the setup steps below.

## Phase 1: Setup (do this once)

1. Parse your join arguments above.

   **If arguments are empty or missing:**
   Run `squad roles` to list available roles, then ask the user which role they want to join as. Do NOT proceed until the user picks a role.

   **If arguments look like a role name** (1-2 words, e.g. "cto", "worker worker-2"):
   - First word is your role — this can be ANY string: "cto", "ceo", "manager", "reviewer", etc. It does NOT need to appear in `squad roles` (that list only shows predefined templates).
   - Optional second word is a custom agent ID
   - If no custom ID provided, use the role name as your ID
   - Examples: "manager" → id=manager, role=manager | "worker worker-2" → id=worker-2, role=worker | "cto" → id=cto, role=cto

   **If arguments look like natural language** (e.g. "加入团队，作为管理员", "join as tech lead and review PRs"):
   - Extract the intended role from the text. Pick a short English role name (e.g. "manager", "reviewer", "cto").
   - Use that as your role and ID.
   - If no role can be inferred, ask the user to clarify.

2. Run `squad init` (safe to run — won't overwrite existing workspace).

3. **Clean up stale agents from previous sessions:**
   Run `squad agents` and check the output.
   - If ALL agents show "stale" (no active agents), tell the user stale squad state was detected and ask the user whether they want to reset squad state with `squad clean` followed by `squad init`. Do NOT clean automatically.
   - If some agents are active (a team is already running), skip cleanup and proceed.

4. Run `squad join <id> --role <role> --client claude --protocol-version 2` to register yourself.
   - Read the output line that says "Joined as ..." — that confirms your actual agent ID.
   - If the ID was taken, squad auto-assigns a suffixed ID (e.g. worker-2). Use that ID for all commands.
   - If role instructions are printed (=== Role Instructions ===), follow them.
   - If no predefined template exists, interpret the role using your own knowledge.

5. Run `squad agents` to see who else is on the team.

6. **If any squad command returns "Session replaced":** another terminal took your ID. Re-join with a different ID (e.g. `squad join worker-2 --role worker --client claude --protocol-version 2`).

## Phase 2: Enter Receive Mode (MANDATORY)

**Immediately after setup, run `squad receive <your-id> --wait` to start listening for messages.** Do NOT wait for the user to tell you — enter receive mode now.

After receiving a message:
1. Execute the task or respond as appropriate for your role.
2. Report results using `squad send` or `squad task` commands.
3. Run `squad receive <your-id> --wait` again to wait for the next message.

If receive times out with no messages, run it again immediately.

Other useful commands:
- `squad send <your-id> <to> "<message>"` — send a message (use @all to broadcast)
- `squad task create <your-id> <to> --title "<title>"` — create a structured task
- `squad agents` — see who is online
- `squad pending` — check all unread messages
- `squad history` — view message history
