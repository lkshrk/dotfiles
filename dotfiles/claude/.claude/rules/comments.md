# Code comments — write almost none

Default to NO comments. A comment must earn its place by explaining a non-obvious WHY: a hidden constraint, a subtle invariant, a workaround for a specific bug, or behavior that would surprise a reader. If deleting the comment wouldn't confuse a competent reader, delete it.

Never write:
- Comments that restate what the code already says (`// loop over tools`, `// set the flag`, `// return error`). Well-named identifiers are the documentation.
- Section/banner/decoration comments (`// ===== helpers =====`), step narration (`// Step 1:`, `// Now we ...`), or comments that echo the function name.
- Comments referencing the current task/PR/fix/ticket (`// added for HCL-x`, `// fix for the Y flow`, `// used by Z`). That belongs in the commit/PR, and it rots.
- Multi-line docstrings or paragraph blocks. One short line max when a comment is truly warranted.
- TODO/notes-to-self left in committed code.

Keep (these are the rare WHY comments worth writing):
- Why a non-obvious approach was chosen over the obvious one.
- A correctness invariant a future edit could silently break (e.g. "map fully written before goroutines start; reads need no lock").
- Why an error is intentionally swallowed/degraded (the documented no-op exception).

This applies to me and to every subagent/implementer I dispatch — include it in their briefs.
