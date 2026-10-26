# dotfiles

Personal macOS and Omarchy config managed by [Omni](https://github.com/lkshrk/omni). Omni owns package reconciliation and dotfile symlinks; this repo only keeps the bootstrap glue and a few local post-sync steps.

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

`towerr` runs [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland). It gets
the same CLI, dev, AI and secrets groups as `topaz`, resolved through `pacman`
and `aur` providers, plus the `omarchy` group (keyd, Hyprland and Omarchy shell
config).

On a fresh Omarchy install:

```sh
git clone https://github.com/lkshrk/dotfiles.git ~/Dev/dotfiles && ~/Dev/dotfiles/setup-omarchy.sh
```

It is safe to rerun.

The setup flow:

1. Installs the latest Omni release (checksum-verified) into `~/.local/bin`
   when the installed Omni cannot read this config.
2. On the first run only, lets the repo's configs replace the fresh defaults:
   volatile agent configs are moved aside as `*.pre-dotfiles.<stamp>` and
   conflicting dots are resolved with `--use-repo` (Omni backs those up).
3. Runs `omni bootstrap --no-import` and `omni tools sync`. Omni installs its
   own prerequisites: GNU Stow before linking dots, and the package managers
   this host lists as tools (bun, uv, ...) before the tools that need them.
   Commands a later step needs that are still missing are reported once, and
   their steps are skipped.
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
   `omarchy/chromium.webapps` as Chromium app windows.
9. Configures rbw (asking for the Bitwarden email and server once), unlocks it
   (which starts the SSH agent used for git signing) and writes the LAN root
   CA from the vault, trusted system-wide (`scripts/lan-ca.sh`).
10. Runs `omni agents sync` (APM plugins and hooks; needs the LAN CA), clones
    the knowledge vault to `~/knowledge` and enables `knowledge-sync.timer`.
11. Installs the Lefthook hooks of this repository and the vault, and checks
    that Hyprland loads the linked config.

Omarchy owns most of `~/.config/hypr` and `~/.config/omarchy` and rewrites them
on refresh, so those dots track only the files listed in their `ignore`
negations (`bindings.lua`, `rules.lua`, `shell.json`, `plugins/`, ...). Editors
that save by replacing the file turn the symlink into a plain copy;
`omni dots status` then reports a conflict, and `omni dots resolve <name>
--use-local` takes the edit back into the repo.

`~/.bashrc` loads Omarchy's bash defaults when they exist, so interactive bash
behaves like a stock Omarchy shell. git uses the `git@topaz` package, whose
GitHub credential helper finds `gh` on `PATH`; commit signing goes through the
rbw SSH agent on both hosts.

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
dotsync                   # omni reconcile
dotcheck                  # omni dots status
dottrack PATH [args...]   # omni dots add --adopt PATH [args...]
```

The `agent-paths` pre-commit hook checks staged shared Claude/Codex JSON and TOML
configs for host-local paths (home directories, temporary directories, mounted
volumes, Homebrew installations and Windows drive paths). `$HOME`, `~` and shared
system paths remain allowed. Explicit `@host` packages are outside this check.
Run `python3 scripts/check-agent-paths.py` to check the current index manually.

### Agent skills

Manage agent dependencies through `omni agents sync`, not direct APM installs
or copies into live skill directories. The host template points to
`apm/ai-plugins/apm.yml`; its `codex` target deploys shared skills into
`~/.agents/skills`, which OMP also discovers. The native `omp` target manages
MCP through Omni's pinned APM fork (`0.35.0+omni.2`, based on release v0.35.0).
Existing Claude-targeted packages remain separate.

- `lkshrk/agent-stack` supplies the `linear`, `personal`, and `runner` packages.
  Runner adds `upgrade-deps`, `project-tool-allowlist`, and `ai-context-generator`.
- `apm/omp-skills` supplies adapted `systematic-debugging` and
  `receiving-code-review` skills from obra/superpowers at
  `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b`, with their MIT licenses.
- The same local package vendors `i-have-adhd` unchanged from
  ayghri/i-have-adhd at `1ecea1993b7fce257ffbd686c070948b5e07eda6`, including
  its license and manual-invocation metadata but no always-on hooks.

In OMP, invoke `/skill:<name>`; for example `/skill:upgrade-deps` or
`/skill:i-have-adhd`. The latter is manual-only and intentionally absent from
the model's automatic skill list. Start a new OMP session after syncing.

For MCP, the host enables `claude`, `codex`, `omp`, and `opencode`. Per-server
`targets` keep `codebase-memory-mcp`, `openaiDeveloperDocs`, and `shiplight` on
Claude/Codex; omp receives only the APM-managed `context-mode` plugin and
`litellm-tools`. The gateway declaration uses `headersHelperKeys` so omp
extracts its authentication header through the existing helper at connection
time. No credential is stored in the manifest or native config.

OpenCode receives `context-mode` from APM in `~/.config/opencode/opencode.json`
and discovers shared skills from `~/.agents/skills` and `~/.claude/skills`;
APM also copies untargeted packages into `~/.config/opencode/skills`, and
OpenCode keeps one skill per name. APM's OpenCode adapter cannot render header helpers,
so `litellm-tools` stays off the `opencode` target and is declared in the
dotfile-managed `opencode.jsonc` with a `{env:LITELLM_API_KEY}` header. See
[env](dotfiles/env/.config/env/README.md) for the wrapper and provider layout.

Do not dotfile-manage `~/.omp/agent/mcp.json` or the deployed shared skills.
APM owns their deployment; omp keeps its local enable/disable controls and
per-server instruction preferences. Changing an existing unmanaged connection
requires explicit resolution before APM can adopt it.

Polly's `investigate`, `cross-review`, and `fanout` bundle is not deployed here:
it requires the Omnigent server's orchestration tools.

APM 0.34 refreshes cached local packages after resolving dependencies. When
adding dependencies inside a local package, the first `omni agents sync` can
refresh that manifest without installing its new children; a second sync
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
  chromium.webapps        # web apps setup installs to open in Chromium
  remove.packages         # Omarchy preinstalls setup removes
  remove.webapps          # Omarchy web apps setup removes
templates/                # copied, not linked: opendeck-images/, obs/
docs/reviews/             # design reviews and evaluations
dotfiles/
  omni/                   # tracked Omni config
  hypr/                   # Hyprland bindings, rules, input, look and feel
  omarchy-shell/          # Omarchy shell.json and custom shell plugins
  yabai/                  # yabai config + sleep-on-lock Swift source
  sleep-on-lock/          # LaunchAgent plist
  ...                     # managed dotfile packages
```
