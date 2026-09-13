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

Coder workspaces use only the composable entrypoint, with explicit tool stacks and agent clients:

```sh
git clone <repo> ~/dotfiles
cd ~/dotfiles
CODER_OMNI_STACKS=go,containers CODER_AGENT_CLIENTS=claude,codex ./setup-coder-components.sh
```

Use `--print-config` to inspect the resolved Omni configuration without installing anything. With no selections, setup installs the core terminal/editor tools and personal Zsh, Neovim, tmux and LazyGit configuration. Language stacks and agent clients are opt-in. Required component failures stop setup; local configuration conflicts are preserved.

The Linux image must provide Python 3, curl, tar, git and jq, with apt and root or passwordless sudo available for missing component packages. The parent Coder template owns Docker daemon provisioning and system CA trust. `CODER_ENABLE_DIND` describes that daemon; the `containers` stack selects Docker tooling. `OMNI_OTEL_CA_PATH` supplies Node's additional CA when explicitly configured. No OpenHands settings, APM skills, agent hooks, marketplace plugins or MCP registrations are implicitly installed. `CODER_MCP_URL` is an explicit override for selected clients only.

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
setup-coder-components.sh # composable Coder bootstrap
scripts/
  coder-bootstrap.sh      # side-effect-free logging, notes and terminfo helpers
  macos-defaults.sh       # optional macOS defaults
dotfiles/
  omni/                   # tracked Omni config
  yabai/                  # yabai config + sleep-on-lock Swift source
  sleep-on-lock/          # LaunchAgent plist
  ...                     # managed dotfile packages
```
