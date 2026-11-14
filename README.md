# dotfiles

Personal macOS and Omarchy config. chezmoi writes the dotfiles and runs the package, mise and agent steps; the setup scripts only bootstrap a machine and do the steps that need root or a desktop session.

## Setup

```sh
git clone <repo> ~/Dev/dotfiles
cd ~/Dev/dotfiles
./setup.sh
```

The setup flow:

1. Verifies Xcode Command Line Tools and `swiftc`.
2. Ensures Homebrew is installed and on `PATH`.
3. Installs the bootstrap tools with Brew: chezmoi and mise.
4. Runs `chezmoi init --apply`: dotfiles, the host's Brewfiles, mise tools and the agent setup (APM).
5. Compiles `~/.local/bin/sleep-on-lock` from the tracked Swift source.
6. Loads `com.lkshrk.sleep-on-lock` as a user LaunchAgent.
7. Loads `com.lkshrk.knowledge-sync` as a user LaunchAgent (runs `~/knowledge/scripts/sync.sh` every 5 minutes; needs the vault clone, see its `scripts/setup.sh`).
8. Refreshes the yabai sudoers entry.
9. Sets rbw's lock timeout, unlocks it and writes the LAN root CA from the
   vault to `~/.local/share/certs/lan-ca.pem` (`scripts/lan-ca.sh`).
10. Installs repository-local Lefthook hooks.

Git hooks use Git's default repository-local directory. Do not set a global
`core.hooksPath`: Lefthook installs from different repositories would share and
overwrite that directory. Run `lefthook install` in each new clone that uses
Lefthook (or its normal package setup). Linked worktrees share their repository's hooks.

Admin-required package actions are handled by normal macOS authentication. Setup warms the sudo session with `sudo -v` when running in an interactive terminal.

Flags:

| Flag | Effect |
| ---- | ------ |
| `--macos-defaults` | Run `scripts/macos-defaults.sh` during setup |

After setup, run:

```sh
claude doctor
```

## Omarchy

`towerr` runs [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland). It has
the same role groups as `topaz` except `macos`, plus `omarchy`
(keyd, Hyprland and Omarchy shell config); see `home/.chezmoidata/hosts.yaml`.

On a fresh Omarchy install:

```sh
git clone https://github.com/lkshrk/dotfiles.git ~/Dev/dotfiles && ~/Dev/dotfiles/setup-omarchy.sh
```

It is safe to rerun.

The setup flow:

1. Installs chezmoi (pacman). Omarchy already ships yay and mise.
2. Runs `chezmoi init --apply`: dotfiles, the host's pacman/AUR lists, mise
   tools and the agent setup (APM). On the first run only, `--force` lets the
   repo's configs replace the fresh defaults without asking.
3. Reports commands a later step needs that are still missing, once, and skips
   those steps.
4. Removes the Omarchy packages and web apps listed in
   `omarchy/remove.packages` and `omarchy/remove.webapps`.
5. Switches the login shell to zsh and installs the keyd Mac keymap from
   `omarchy/keyd/` (Cmd sends Ctrl, Caps Lock is Hyper).
6. Adds the managed `/etc/fstab` block from `omarchy/fstab.mounts` with the
   units in `omarchy/systemd/`, keeps the STUFF Steam library's Proton
   prefixes on the home disk, and applies the system tweaks (cloudflared,
   `omarchy/default/irqbalance`, one ufw rule).
7. Copies the Stream Deck images from `templates/opendeck-images/` and, on a
   machine without OBS scenes, applies `templates/obs/` with `obs-config`.
8. Enables Docker with sudoless access, makes Helium the default browser and
   File Roller the archive handler, and installs the web apps in
   `omarchy/webapps` as app windows, each its own Helium instance.
9. Configures rbw (asking for the Bitwarden email and server once), unlocks it
   (which starts the SSH agent used for git signing) and writes the LAN root
   CA from the vault, trusted system-wide (`scripts/lan-ca.sh`).
10. Clones the knowledge vault to `~/knowledge` and enables `knowledge-sync.timer`.
11. Installs the Lefthook hooks of this repository and the vault, and checks
    that Hyprland loads its config.

Omarchy owns most of `~/.config/hypr` and `~/.config/omarchy` and rewrites them
on refresh. chezmoi writes only the files the repo tracks (`bindings.lua`,
`rules.lua`, `shell.json`, `plugins/`, ...) and leaves the rest alone. After an
Omarchy update, the `check-dots-links` hook reports managed files that changed;
`chezmoi diff` shows them and `chezmoi re-add` takes a change into the repo.

## Dotfiles (chezmoi)

chezmoi copies files from `home/` into `$HOME` (`.chezmoiroot`). No symlinks:
edits in `$HOME` don't change the repo until you take them back (`dotpush`).
Every tracked file is managed, including configs apps rewrite (Zed, OpenDeck,
Omarchy `shell.json`). For an exception, rename the source file with a
`create_` prefix (written once if missing, then left to the app), or list the
target in `home/.chezmoiignore` (never touched).

```sh
chezmoi diff                # what apply would change
chezmoi apply               # write the repo's files into $HOME
chezmoi re-add [PATH]       # take edits made in $HOME back into the repo
chezmoi edit PATH           # edit the source of a managed file
chezmoi add PATH            # start managing a file
chezmoi status              # managed files that differ, either direction
```

- Hosts and their groups are listed in `home/.chezmoidata/hosts.yaml`. A
  group's files are skipped on hosts without it (`home/.chezmoiignore`).
- Host differences are `{{ if }}` blocks in the file's own template
  (`dot_config/git/config.tmpl`, `dot_zshrc.tmpl`); `home/.chezmoitemplates/`
  holds snippets the scripts share.
- Source names follow chezmoi: `dot_config/` for `.config/`, `executable_`
  for scripts, `symlink_` for the few links that stay links.
- `scripts/render-home.sh <host>` writes a host's files into a temp directory;
  tests that need deployed names use it.
- zsh helpers: `dotsync` (`chezmoi update`), `dotcheck` (`chezmoi status`),
  `dottrack PATH` (`chezmoi add`), `dotpush [PATH]` (`chezmoi re-add`).

**Moving a host from the old Stow links to chezmoi** (topaz, the work Mac): pull,
then run `scripts/migrate-to-chezmoi.sh --dry-run` to see the plan and
`scripts/migrate-to-chezmoi.sh` to do it. It records the old links under
`~/.local/state/dotfiles-migration/`, copies git-ignored files that old links
still reach (such as `gh/hosts.yml`) into place, runs `chezmoi init --apply
--force`, re-links systemd `.wants` links, reloads the `com.lkshrk.*`
LaunchAgents on macOS and removes stale links. Then it verifies:
- `chezmoi verify` and `chezmoi status` are clean;
- no old links are left;
- systemd links resolve;
- Hyprland reports no config errors.

It exits non-zero if any check fails. It is safe to rerun.
`tests/migrate-to-chezmoi.sh` runs it end to end in a throwaway `HOME`.

`~/.bashrc` loads Omarchy's bash defaults when they exist, so interactive bash
behaves like a stock Omarchy shell. The git config's GitHub credential helper
(every host but the work Mac) finds `gh` on `PATH`; commit signing goes through
the rbw SSH agent on both personal hosts.

## Packages and tools

Each role group in `home/.chezmoidata/hosts.yaml` can bring:

| Layer | File | Installed by |
|---|---|---|
| macOS packages | `packages/brew/<group>.Brewfile` | `brew bundle --no-upgrade` |
| Arch packages | `packages/arch/<group>.pacman`, `<group>.aur` | `pacman -S --needed` (pkexec), `yay -S --needed` |
| CLIs and runtimes | `home/dot_config/mise/conf.d/<group>.toml` | `mise install` |
| macOS-only mise tools | darwin block in `…/conf.d/<group>.toml.tmpl` | rendered only on macOS |

chezmoi runs `home/.chezmoiscripts/` on apply: the package and mise scripts rerun
whenever one of the host's lists changes; they only install what is missing.
Anything Omarchy ships (its package lists, or its own mise layer in
`/etc/mise/conf.d`) stays out of our lists, and so does whatever the OS or
Omarchy installer put on a host (`packages/installer/<host>.txt`, used only by
the drift check); `tests/package-lists.sh` checks both. oh-my-zsh, its plugins
and the tmux plugins are chezmoi git externals (`home/.chezmoiexternal.toml`),
cloned on first apply and pulled by `scripts/update.sh`.

```sh
scripts/update.sh           # upgrade packages, mise tools and dotfiles, then report drift
scripts/update.sh --check   # drift only: unlisted or missing packages, missing mise tools, dotfile changes
```

## Checks

The `agent-paths` pre-commit hook checks staged shared Claude/Codex JSON and TOML
configs for host-local paths (home directories, temporary directories, mounted
volumes, Homebrew installations and Windows drive paths) under `home/dot_claude/`
and `home/dot_codex/`. `$HOME`, `~` and shared system paths remain allowed.
Files in `home/.chezmoitemplates/` are outside this check.
Run `python3 scripts/check-agent-paths.py` to check the current index manually.

### Agent skills

Agent dependencies are declared in `apm/ai-plugins/apm.yml`, never installed
into live skill directories by hand. chezmoi writes the global manifest
`~/.apm/apm.yml`, which points at it, and its APM script runs
`apm install -g --trust-transitive-mcp` when a manifest changes;
`scripts/update.sh` refreshes the refs. APM is the patched build from
`lkshrk/apm` (branch `lk`: omp target, MCP secrets stay references), pinned by
version and sha256 in `home/.chezmoiscripts/run_onchange_after_50-apm.sh.tmpl`.
The `codex` target deploys shared skills into `~/.agents/skills`, which OMP also
discovers.

- `lkshrk/useful-skills` supplies the `linear-*`, `wow-*`, `upgrade-deps`,
  `project-tool-allowlist`, `ai-context-generator` and other personal skills.
- `apm/omp-skills` vendors `i-have-adhd` unchanged from
  ayghri/i-have-adhd at `1ecea1993b7fce257ffbd686c070948b5e07eda6`, including
  its license and manual-invocation metadata but no always-on hooks. Codex gets
  the superpowers skills from its own `superpowers@openai-curated` plugin.

In OMP, invoke `/skill:<name>`; for example `/skill:upgrade-deps` or
`/skill:i-have-adhd`. The latter is manual-only and intentionally absent from
the model's automatic skill list. Start a new OMP session after syncing.

For MCP, the host enables `claude`, `codex`, `omp`, and `opencode`. Per-server
`targets` keep `codebase-memory-mcp`, `openaiDeveloperDocs`, and `shiplight` on
Claude/Codex. `litellm-tools` goes to Claude, Codex and omp with the header
`x-litellm-api-key: ${LITELLM_API}`: a reference, never the value, supplied at
launch by `agent-run`. context-mode is installed as native Claude and Codex
plugins, not through APM, because it rewrites its own config.

OpenCode discovers shared skills from `~/.agents/skills` and `~/.claude/skills`;
APM also copies untargeted packages into `~/.config/opencode/skills`, and
OpenCode keeps one skill per name. `litellm-tools` stays off the `opencode`
target and is declared in the dotfile-managed `opencode.jsonc` with a
`{env:LITELLM_API_KEY}` header. See
[env](home/dot_config/env/README.md) for the wrapper and provider layout.

Do not dotfile-manage `~/.omp/agent/mcp.json` or the deployed shared skills.
APM owns their deployment; omp keeps its local enable/disable controls and
per-server instruction preferences. Changing an existing unmanaged connection
requires explicit resolution before APM can adopt it.

Generic omp extensions and portable command hooks are APM-owned runtime output.
Native package extensions require explicit `extensions` approval and can use
omp's native ExtensionAPI. Portable hooks deliberately support only the shared
command-event contract; unsupported lifecycle and native tool shapes fail before
deployment. Do not add generated `.omp/extensions/`, `.omp/hooks.json`, or
`.omp/apm-hooks-runtime.json` to dots.

Polly's `investigate`, `cross-review`, and `fanout` bundle is not deployed here:
it requires the Omnigent server's orchestration tools.

APM 0.34 refreshes cached local packages after resolving dependencies. When
adding dependencies inside a local package, the first `apm install -g` can
refresh that manifest without installing its new children; a second run
resolves the refreshed graph. Its dry-run compares only root dependencies
against the lock and can incorrectly report transitive packages as removals.
Verify the applied dependency graph and OMP skill discovery, not just exit status.

## Layout

```text
setup.sh                  # macOS bootstrap
setup-omarchy.sh          # Omarchy bootstrap
scripts/
  macos-defaults.sh       # optional macOS defaults
  lan-ca.sh               # LAN root CA from the vault, trusted on Linux
  lib/setup-common.sh     # helpers shared by setup.sh and setup-omarchy.sh
omarchy/                  # files setup-omarchy.sh installs outside $HOME
  keyd/                   # Mac keymap per keyboard, installed to /etc/keyd
  systemd/, fstab.mounts  # STUFF and NAS mounts, cloudflared drop-in
  default/irqbalance      # /etc/default/irqbalance
  webapps                 # web apps setup installs, each its own Helium instance
  remove.packages         # Omarchy preinstalls setup removes
  remove.webapps          # Omarchy web apps setup removes
templates/                # copied by setup: opendeck-images/, obs/
.chezmoiroot              # "home": chezmoi's source state
home/                     # files chezmoi writes into $HOME
  .chezmoidata/hosts.yaml # hosts and their groups
  .chezmoiignore          # skips a group's files on hosts without it
  .chezmoitemplates/      # snippets shared by .chezmoiscripts
  dot_config/hypr/        # Hyprland bindings, rules, input, look and feel
  dot_config/omarchy/     # Omarchy shell.json and custom shell plugins
  dot_config/yabai/       # yabai config + sleep-on-lock Swift source
  ...
packages/                 # Brewfiles and pacman/AUR lists per role group
```
