# Root commands: pkexec, not sudo

On Linux, run a command that needs root as `pkexec <command>`. It opens a graphical password prompt for the user.

- Never ask the user to copy and paste a `sudo` command, and never run plain `sudo`: it can't prompt without a terminal.
- `pkexec` resets the environment and working directory: use absolute paths, and pass variables explicitly (`pkexec env FOO=1 /usr/bin/cmd`).
- Every call prompts again, so batch root steps into one call where that's safe (`pkexec sh -c '…'`).
- If `pkexec` fails with "No authentication agent found" or the user dismisses the prompt, say so and stop. Don't fall back to `sudo` or ask for a password.
- A root command still needs the same care as any other: say what it does before running it, and never install system services or change the real user systemd without asking.

This applies to me and to every subagent I dispatch.
