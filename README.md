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
5. Runs `omni --config dotfiles/omni/.config/omni/settings.json --yes reconcile`.
6. Compiles `~/.config/yabai/sleep-on-lock` from the tracked Swift source.
7. Loads `com.lkshrk.sleep-on-lock` as a user LaunchAgent.
8. Refreshes the yabai sudoers entry.
9. Installs lefthook hooks.

Admin-required package actions are handled by normal macOS authentication. Setup warms the sudo session with `sudo -v` unless `--skip-admin-warmup` is passed.

Flags:

| Flag | Effect |
| ---- | ------ |
| `--macos-defaults` | Run `scripts/macos-defaults.sh` after Omni reconcile |
| `--skip-admin-warmup` | Skip the initial `sudo -v` |

`install.sh` is a compatibility shim that delegates to `setup.sh`.

After setup, run:

```sh
claude doctor
```

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
install.sh                # compatibility shim for setup.sh
scripts/
  macos-defaults.sh       # optional macOS defaults
dotfiles/
  omni/                   # tracked Omni config
  yabai/                  # yabai config + sleep-on-lock Swift source
  sleep-on-lock/          # LaunchAgent plist
  ...                     # managed dotfile packages
```
