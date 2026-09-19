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
7. Refreshes the yabai sudoers entry.
8. Installs lefthook hooks.

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

The zsh helpers mirror those commands:

```sh
dotsync                   # omni reconcile
dotcheck                  # omni dots status
dottrack PATH [args...]   # omni dots add --adopt PATH [args...]
```

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
