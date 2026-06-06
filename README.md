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
4. Runs `omni --config dotfiles/omni/.config/omni/settings.json --yes bootstrap`.
5. Compiles `~/.local/bin/sleep-on-lock` from the tracked Swift source.
6. Loads `com.lkshrk.sleep-on-lock` as a user LaunchAgent.
7. Refreshes the yabai sudoers entry.
8. Installs lefthook hooks and restores agent skills from the lockfile.

Admin-required package actions are handled by normal macOS authentication. Setup warms the sudo session with `sudo -v` when running in an interactive terminal.

Flags:

| Flag | Effect |
| ---- | ------ |
| `--macos-defaults` | Run `scripts/macos-defaults.sh` during setup |

After setup, run:

```sh
claude doctor
```

## Coder

Coder/Linux workspaces use a separate Omni host profile instead of the macOS setup path:

```sh
git clone <repo> ~/dotfiles
cd ~/dotfiles
./setup-coder.sh
```

`setup-coder.sh` selects `OMNI_HOSTNAME=coder`, installs the minimal Linux prerequisites for Omni, then lets Omni sync the `coder` host's tools and dotfiles.

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
setup.sh                  # primary bootstrap script
setup-coder.sh            # Coder/Linux bootstrap through Omni host profile
scripts/
  macos-defaults.sh       # optional macOS defaults
  setup-coder-linux.sh    # minimal Linux prerequisites for Coder
dotfiles/
  omni/                   # tracked Omni config
  yabai/                  # yabai config + sleep-on-lock Swift source
  sleep-on-lock/          # LaunchAgent plist
  ...                     # managed dotfile packages
```
