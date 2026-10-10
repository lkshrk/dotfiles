# dotfiles

Personal macOS config managed by [Omni](https://github.com/lkshrk/omni). Omni owns package reconciliation and dotfile symlinks; this repo only keeps the bootstrap glue and a few local post-sync steps.

## Setup

```sh
git clone <repo> ~/Dev/dotfiles
cd ~/Dev/dotfiles
./setup.sh
```

The setup flow:

1. Verifies Xcode Command Line Tools and `swiftc`.
2. Ensures Homebrew is installed and on `PATH`.
3. Installs the bootstrap tools with Brew: GNU Stow, Omni, Bun, and uv.
4. Runs `omni bootstrap --no-import`, then `omni tools sync` for the host's tools and agent state.
5. Compiles `~/.local/bin/sleep-on-lock` from the tracked Swift source.
6. Loads `com.lkshrk.sleep-on-lock` as a user LaunchAgent.
7. Loads `com.lkshrk.knowledge-sync` as a user LaunchAgent (runs `~/knowledge/scripts/sync.sh` every 5 minutes; needs the vault clone, see its `scripts/setup.sh`).
8. Refreshes the yabai sudoers entry.
9. Installs repository-local Lefthook hooks.

Git hooks use Git's default repository-local directory. Do not set a global
`core.hooksPath`: Lefthook installs from different repositories would share and
overwrite that directory. Run `lefthook install` in each new clone that uses
Lefthook (or its normal package setup); Coder setup does this automatically for
configured repositories. Linked worktrees share their repository's hooks.

Admin-required package actions are handled by normal macOS authentication. Setup warms the sudo session with `sudo -v` when running in an interactive terminal.

Flags:

| Flag | Effect |
| ---- | ------ |
| `--macos-defaults` | Run `scripts/macos-defaults.sh` during setup |

After setup, run:

```sh
claude doctor
```

## Linux workspaces

This repository only ever provisions personal configuration for Coder workspaces: the core terminal/editor dotfiles (Zsh, Neovim, tmux, LazyGit, ...) plus, for each selected agent client, that client's own settings. It has no opinion on which language stacks or tool packages a workspace installs -- that's `lkshrk/auto-code-env`'s `install-stacks.py`, which runs first and owns the Coder-specific tool catalog. This repo's own Omni tool provider catalog (`settings.d/tools.json`, the same one macOS's `setup.sh` uses) is merged into that installer's config natively via Omni's `$include`, not called from here.

```sh
git clone <repo> ~/dotfiles
cd ~/dotfiles
CODER_AGENT_CLIENTS=claude,codex ./setup-coder-dots.sh
```

Use `--print-config` to inspect the resolved Omni configuration without syncing anything. With no client selected, setup only syncs the core personal configuration. Agent clients are opt-in. Required dots failures stop setup; local configuration conflicts are preserved.

This script expects `omni`, `jq`, `git` and `python3` already on `PATH` (auto-code-env's installer guarantees `omni` before calling this). No OpenHands settings, APM skills, agent hooks, marketplace plugins or MCP registrations are implicitly installed. `CODER_MCP_URL` is an explicit override for selected clients only.

## Omni

This repo uses the tracked config:

```sh
dotfiles/omni/.config/omni/settings.json
```

Use it explicitly when running Omni from a fresh shell:

```sh
omni --config ~/Dev/dotfiles/dotfiles/omni/.config/omni/settings.json reconcile
```

The equivalent environment variable is:

```sh
export OMNI_CONFIG=~/Dev/dotfiles/dotfiles/omni/.config/omni/settings.json
```

Useful commands:

```sh
omni reconcile             # sync tools, upgrade, repair dots, commit dot changes
omni dots status           # dotfile symlink health + repo status
omni dots discover         # untracked dotfile candidates
omni dots add --adopt PATH # adopt a local path into dotfile management
omni dots sync [name]      # repair all dots or one dot entry
```

Use the zsh helpers for routine reconciliation:

```sh
dotsync                   # omni reconcile, preserving local agent state
dotcheck                  # omni dots status
dottrack PATH [args...]   # omni dots add --adopt PATH [args...]
```

`setup.sh`, `dotsync`, and Coder setup keep files in `scripts/volatile-dots.txt`
as local copies. Claude/Codex can then write machine-specific state without
changing the shared templates. Existing local settings are preserved, so merge
intentional template changes into those local configs explicitly. Codex project
trust and hook approval records stay local; do not replace their paths with `~`.
Direct `omni dots sync --use-repo` bypasses this protection and can recreate
writable links; use `dotsync` for routine syncs.

The `agent-paths` pre-commit hook checks staged shared Claude/Codex JSON and TOML
configs for host-local paths (home directories, temporary directories, mounted
volumes, Homebrew installations and Windows drive paths). `$HOME`, `~` and shared
system paths remain allowed. Explicit `@host` packages are outside this check.
Run `python3 scripts/check-agent-paths.py` to check the current index manually.

## Layout

```text
setup.sh                  # macOS bootstrap
setup-coder-dots.sh       # Coder workspace personal-dots sync
scripts/
  coder-bootstrap.sh      # side-effect-free logging, notes and terminfo helpers
  macos-defaults.sh       # optional macOS defaults
dotfiles/
  omni/                   # tracked Omni config
  yabai/                  # yabai config + sleep-on-lock Swift source
  sleep-on-lock/          # LaunchAgent plist
  ...                     # managed dotfile packages
```
