# dotfiles

Personal macOS and Omarchy config. chezmoi writes the dotfiles and runs every idempotent step as a chezmoi script; `setup.sh` only bootstraps a machine and does the steps that need a person.

## Setup

```sh
git clone https://github.com/lkshrk/dotfiles.git ~/Dev/dotfiles && ~/Dev/dotfiles/setup.sh
```

`setup.sh` works on macOS and Omarchy and is safe to rerun:

1. Gets the package manager and chezmoi: on macOS the Xcode Command Line Tools,
   Homebrew, then `brew install chezmoi mise`; on Omarchy `pacman -S chezmoi`
   through pkexec (Omarchy ships yay and mise).
2. Runs `chezmoi init --source <repo>` and `chezmoi apply`. Without
   `~/.config/chezmoi/chezmoi.toml` (a first run) it adds `--force`, so the
   repo's configs replace the fresh defaults without asking.
3. Configures rbw (Bitwarden email and server once, no lock timeout) and
   unlocks it. On Omarchy it then clones the knowledge vault to `~/knowledge`
   and, on a machine without OBS scenes, applies `templates/obs/` with `obs-config`.
4. Runs `chezmoi apply` again for the steps that waited for the vault (LAN root
   CA, knowledge-sync agent) and, inside Hyprland, checks the config loads.

Everything else is a script in `home/.chezmoiscripts/`, gated by host group and
rerun by `chezmoi apply` when its inputs change:

| Script | Hosts | Does |
|---|---|---|
| `10-packages`, `20-mise`, `30-rust`, `40-agent-extras`, `50-apm` | per group | packages, mise tools, agents |
| `55-lan-ca` | personal | LAN root CA from the vault to `~/.local/share/certs/lan-ca.pem` once rbw is unlocked |
| `60-omarchy-system` | omarchy | `/etc` from `omarchy/` (keyd, fstab mounts, units, cloudflared, irqbalance, ufw, CA trust, keyd/docker groups, zsh login shell) in one pkexec call, only when something differs |
| `61-omarchy-apps` | omarchy | removes `omarchy/remove.*`, installs `omarchy/webapps`, Helium and File Roller as defaults |
| `62-omarchy-user` | omarchy | clones the Omarchy shell plugins if missing; Steam Proton prefixes off the NTFS library |
| `63-systemd-user` | omarchy | daemon-reload when a user unit changes; units are enabled by the `.wants` links chezmoi writes |
| `70-macos-defaults` | macOS | Finder and keyboard defaults |
| `71-sleep-on-lock`, `72-yabai-sudoers` | macos | builds and loads the sleep-on-lock agent; refreshes the yabai sudoers entry (prints the command when there is no terminal) |
| `73-knowledge-sync-agent` | personal Macs | loads the knowledge-sync LaunchAgent once `~/knowledge` exists |
| `80-lefthook` | dev | `lefthook install` in this repo |

Git hooks use Git's default repository-local directory. Do not set a global
`core.hooksPath`: Lefthook installs from different repositories would share and
overwrite that directory. Run `lefthook install` in each new clone that uses
Lefthook (or its normal package setup). Linked worktrees share their repository's hooks.

After setup, run:

```sh
claude doctor
```

## Omarchy

`towerr` runs [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland). It has
the same role groups as `topaz` except `macos`, plus `omarchy`
(keyd, Hyprland and Omarchy shell config) and `audio`; see `home/.chezmoidata/hosts.yaml`.
The shell plugins `~/Dev/omarchy-stats` and `~/Dev/omarchy-quotatank` are
cloned if missing by `run_after_62-omarchy-user` (working copies, never pulled);
the Stream Deck images are `create_` files, written once and then left to OpenDeck.

Omarchy owns most of `~/.config/hypr` and `~/.config/omarchy` and rewrites them
on refresh. chezmoi writes only the files the repo tracks (`bindings.lua`,
`rules.lua`, `shell.json`, `plugins/`, ...) and leaves the rest alone. After an
Omarchy update, the `check-dots-links` hook reports managed files that changed;
`chezmoi diff` shows them and `chezmoi re-add` takes a change into the repo.

### Audio

The `audio` group (one block in `home/.chezmoiignore`) holds the USB mic and
PipeWire setup. The files sit where each program reads them:

| File | Purpose |
|---|---|
| `pipewire/pipewire.conf.d/mic-clock.conf` | Always-present timer that clocks the mic graph, so a USB replug doesn't stall it |
| `pipewire/pipewire.conf.d/min-quantum.conf` | Graph quantum floor of 512 at 48 kHz (lower makes PipeWeaver xrun) |
| `pipewire/filter-chain.conf.d/mic-filtered.conf` | "Mic (filtered)": the RODE, or the Razer headset when out of the RODE's range |
| `wireplumber/wireplumber.conf.d/usb-mic-quantum.conf` | USB mic: fixed quantum, joins the `mic-clock` group |
| `wireplumber/wireplumber.conf.d/hide-devices.conf` | Hides GPU HDMI audio, the RODE headphone jack and the raw RODE source |
| `wireplumber/wireplumber.conf.d/pipeweaver-no-restore.conf` | No mute restore for PipeWeaver nodes (avoids a mute/unmute loop) |
| `systemd/user/pipewire.service.d/log-xruns.conf` | Logs xruns and ALSA resyncs to the journal |
| `systemd/user/pipeweaver.service` (+ `graphical-session.target.wants` link) | Pipeweaver mixer daemon |
| `~/.local/bin/pipeweaver-app`, `pipeweaver.desktop` | Pipeweaver UI launcher |
| `hypr/scripts/audio-restart` | Restarts the audio stack; `audio-restart` / `mic-reset` (`env/functions/audio`) |

## Dotfiles (chezmoi)

chezmoi copies files from `home/` into `$HOME` (`.chezmoiroot`). No symlinks:
edits in `$HOME` don't change the repo until you take them back (`dotpush`).
Every tracked file is managed, including configs apps rewrite (OpenDeck,
Omarchy `shell.json`). Zed's `settings.json` is a `modify_` template: it keeps
the live file and replaces only the gateway URLs and model lists from
`home/.chezmoidata/models.yaml` (comments in the live file are dropped). For
an exception, rename the source file with a `create_` prefix (written once if
missing, then left to the app), or list the target in `home/.chezmoiignore`
(never touched).

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

**Stow to chezmoi** (the two Macs still on the old links): pull, then
`scripts/migrate-to-chezmoi.sh --dry-run` shows the plan and
`scripts/migrate-to-chezmoi.sh` does it and verifies. It is safe to rerun.

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

## Tests

Each file in `tests/` is standalone and runs against a rendered tree
(`scripts/render-home.sh`), with fake binaries where needed:

```sh
bash tests/render-hosts.sh     # every host's scripts render and pass bash -n and shellcheck
sh tests/env-smoke.sh          # .sh tests: sh or bash per shebang
python3 tests/local-agents-token.py
lua tests/hypr-screens-snap.lua   # from the repo root
lefthook run pre-push          # everything below except the migration test
```

The `pre-push` hook runs all of them in parallel, a few seconds in total.
`tests/migrate-to-chezmoi.sh` clones the repo and runs the migration in a
throwaway `HOME`; it is slow, so run it by hand.

GitHub Actions (`.github/workflows/ci.yml`) runs the `pre-push` list on Ubuntu
(`nvim-omarchy-theme` skips there: no Omarchy themes or lazy plugins), and on
macOS renders the Mac hosts with the real OS, runs `tests/macos-scripts.sh`
(bash 3.2, no bash-4 syntax, `zsh -n`) and `tests/brewfile-entries.sh` (every
Brewfile entry resolves with `brew info`; needs brew and network).

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
`apm install -g --trust-transitive-mcp` when a manifest changes. Every git
dependency is pinned with `ref: <commit>`; `scripts/update.sh` installs the
pins and never moves them (`apm update` would not either: it only moves SHA pins
to annotated release tags, which most of these repositories lack, and skips
local packages like `ai-plugins`). To bump, run `scripts/update.sh --bump-apm`
in `~/Dev/dotfiles`: it sets each pin to its upstream's `HEAD`, installs, and
leaves the manifest for you to review and commit; to bump one dependency, edit
its `ref:` by hand. Local `path:` dependencies cannot be pinned. APM is the patched build from
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
setup.sh                  # bootstrap for macOS and Omarchy
omarchy/                  # inputs of the Omarchy chezmoi scripts, installed outside $HOME
  keyd/                   # Mac keymap per keyboard, installed to /etc/keyd
  systemd/, fstab.mounts  # STUFF and NAS mounts, cloudflared drop-in
  default/irqbalance      # /etc/default/irqbalance
  webapps                 # web apps, each its own Helium instance
  remove.packages         # Omarchy preinstalls to remove
  remove.webapps          # Omarchy web apps to remove
templates/obs/            # OBS scenes, applied by obs-config
scripts/                  # update.sh, render-home.sh, migrate-to-chezmoi.sh, check-agent-paths.py
tests/                    # standalone tests; pre-push runs them (see Tests)
types/                    # Lua type stubs for the Hammerspoon and Omarchy configs
apm/                      # APM manifests: ai-plugins (agent dependencies), omp-skills (vendored skill)
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
