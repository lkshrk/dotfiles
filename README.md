# dotfiles

Personal macOS config, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Per-host layout: shared defaults plus host-specific overrides keyed on `hostname -s`.

## Install

```sh
git clone <repo> ~/Dev/dotfiles
cd ~/Dev/dotfiles
./install.sh
```

The installer:

1. Installs Homebrew + base brew bundle (skippable).
2. Stows every package into `$HOME` (`--no-folding`, `--adopt`).
3. Adopts any existing real files in `$HOME` into the repo, backing the
   originals up to `~/.dotfiles-backup/<timestamp>/`. Prompts before
   overwriting a newer repo version with an older home copy.
4. Offers an opt-in 7-day shell-start reminder to run `dotsync`.

Flags:

| Flag            | Effect                                         |
| --------------- | ---------------------------------------------- |
| `--skip-brew`   | Skip Homebrew install + bundle                 |
| `--no-prompt`   | Assume "yes" for safe prompts, "no" for destructive ones |

## Packages

One stow package per directory:

```
brew        zsh        git      gh       nvim     opencode
ghostty     tmux       hammerspoon
linearmouse skhd       yabai    zed      ssh      claude
```

Each package mirrors its target path under `$HOME`, so
`hammerspoon/.config/hammerspoon/init.lua` → `~/.config/hammerspoon/init.lua`.

## Per-host config

Host overrides live in `hosts/<hostname>.conf` and
`hammerspoon/.config/hammerspoon/config_<hostname>.lua`. A shared
`config_shared.lua` is deep-merged with the host config at runtime;
per-key overrides win on conflict.

Supported hosts: `Topaz`, `APM3LJHMVG7XGCF`. Unknown hosts fall back to
`default`.

## Day-to-day

Three commands cover the whole loop:

```sh
dotcheck                # list repo drift + untracked $HOME candidates
dottrack <path> [pkg]   # start tracking a $HOME file: mv into repo + restow + stage
dotsync                 # absorb drift on already-tracked files, restow, auto-commit
```

`dotsync` does **not** pull in new files — that's `dottrack`'s job. Typical flow:

1. Edit a tracked file. Symlink routes the write straight into the repo.
2. New file you want tracked? `dottrack ~/.config/foo/bar.toml`.
3. `dotsync` to absorb any atomic-write drift and commit.

`dotsync` flags: `--dry-run`, `--no-commit`, `--yes`.

Phases of `dotsync`:

1. **Adopt drift** — `stow --adopt` absorbs any tracked file that got
   clobbered into a real file. Shows a diff and prompts before keeping.
2. **Restow** — recreate symlinks.
3. **Commit** — auto-commit staged changes.

## Sync reminder (optional)

Enabled via `~/.cache/zsh/dotfiles-sync-reminder`.

Shell-start flow (`zsh/.config/zsh/80-sync-reminder.zsh`):

1. If `dotfiles-last-sync` is <7d old → silent return (~130µs).
2. Otherwise read `dotfiles-drift-check` cache.
   - Stale (>24h) → fire `scripts/drift-check.sh &!` in background, exit
     quiet. Next shell reads the fresh result.
   - `yes` → print `⚠  … run dotcheck to inspect, dotsync to update`.
   - `no` → silent.

`dotsync` and `install.sh` both reset the stamp + cache so the reminder
quiets immediately after a successful sync.

`dotcheck` reports three buckets:

- **repo drift** — uncommitted changes in the repo.
- **new $HOME candidates** — non-symlink files in already-tracked dirs
  whose hypothetical repo path is not gitignored. Add with `dottrack`.
- **unknown ~/.config subdirs** — dirs with no matching stow package.
  Add with `dottrack` or silence with `<name>/.config/<name>/` in `.gitignore`.

## Layout

```
install.sh               # idempotent installer
scripts/
  sync.sh                # dotsync: drift-absorb + restow + commit
  track.sh               # dottrack: move a $HOME file into the repo
  drift-check.sh         # dotcheck: list drift + untracked candidates
  pre-push-sync.sh       # lefthook hook
  macos-defaults.sh      # optional macOS tweaks
  install-claude-plugins.sh
hosts/
  <hostname>.conf        # per-host env + feature flags
<package>/               # one dir per stow package
```
