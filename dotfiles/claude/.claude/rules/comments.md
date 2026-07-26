# Code comments — write almost none

Default: NO comment. When one is truly warranted, hard cap: ONE short line. A multi-line comment paragraph is banned outright — if the explanation needs a paragraph, it belongs in the commit message or a design doc, never in the code.

The litmus test, applied to every comment before writing it: **does this explain the code to someone reading it cold in six months, or justify the change to someone reviewing it today?** Reviewer-talk is banned *even when phrased as a "why"*: no narrating correctness ("what matters here is...", "which the checks above already establish"), no defending the chosen approach, no explaining what the diff does or that it handles a case correctly. All of that goes in the commit/PR description. If the sentence could move to the commit message with zero loss to a future reader, it is not a comment.

Never write:
- Comments restating what the code says (`// loop over tools`, `// return error`). Well-named identifiers are the documentation.
- Banner/section/decoration comments (`// ===== helpers =====`), step narration (`// Step 1:`, `// Now we ...`).
- Comments referencing the current task/PR/fix/ticket (`// added for HCL-x`, `// fix for the Y flow`).
- TODO/notes-to-self in committed code.

Rare keeps — a non-obvious fact about the code a future edit or reader needs, each still one line:
- Why a non-obvious approach was chosen over the obvious one.
- A correctness invariant a later edit could silently break (e.g. "map fully written before goroutines start; reads need no lock").
- Why an error is intentionally swallowed/degraded.
- A workaround for a specific bug, or behavior that would genuinely surprise.

If deleting the comment wouldn't confuse a competent reader, delete it.

This applies to me and to every subagent/implementer I dispatch — include it in their briefs.
