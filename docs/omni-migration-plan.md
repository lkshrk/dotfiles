# Replacing omni with specialized tools

Status: draft, 2026-11-14. Decisions from the first review are recorded at the end. Nothing has been
changed yet.

## Goal

One owner per layer, each a mature tool with its own docs. omni currently owns all of these layers through
one Go binary, its settings schema, and a private APM build.

| Layer | Today (omni) | New owner |
|---|---|---|
| Dotfiles | omni → GNU Stow (symlinks) | **chezmoi**, copying files (no symlinks) |
| OS packages, GUI apps, fonts, drivers | omni → brew / pacman / AUR / apt | **Brewfiles** (macOS), **pacman + AUR lists** (Arch, `yay`), applied by chezmoi scripts |
| CLI and dev tools, language runtimes | omni → brew / pacman / scripts / bun / uv / npm | **mise** (global config, one file per group) |
| Agent CLIs (claude, codex, omp, opencode) | omni → curl script / bun | **mise** with `auto_update`. On towerr, Omarchy's own mise layer already provides them |
| Agent plugins, skills, MCP | omni → private APM fork | **APM fork** (pinned wheel, `uv tool install`), run directly with `apm install -g` |
| Secrets for agents | `bin/agent-run` + rbw envmaps | unchanged |
| Bootstrap and updates | `omni bootstrap`, `omni tools sync` | `chezmoi init --apply` on a new machine; `chezmoi update` plus `update.sh` afterwards |

Inputs this plan rests on:

- omni settings: 234 tools, 30 groups, 3 hosts (`topaz`, `apm3ljhmvg7xgcf` = work Mac, `towerr`).
- `mise registry` (mise 2026.11.7) and the mise and chezmoi docs.
- Upstream install docs for the special cases (`~/.cache/omni-migration/install-research.md`, with a source
  URL per tool).

## What mise can and cannot do

**Can do:**

- Single-binary CLIs from the registry. 88 of our 234 tools are in it by name, 69 of them through aqua
  (checksums, and signatures where the upstream publishes them).
- Anything else through its generic backends: `npm:`, `pypi:` (alias `pipx:`, installs with uv), `cargo:`,
  `go:` and `github:` (release assets).
- Language runtimes: `core:node`, `core:bun`, `core:go`, `core:python`, `core:java`, and `core:rust`
  (which wraps rustup).
- Per-OS tools in one file: `tool = { version = "latest", os = ["macos"] }`, also `macos/arm64`.
- Groups: `~/.config/mise/conf.d/*.toml` are all loaded, in alphabetical order.
- A lockfile for global tools (`mise lock --global`). By default mise skips releases younger than 24 hours
  (`minimum_release_age`).
- Updates: `mise upgrade --global`, `mise outdated --global`. Per-tool `auto_update = "4h"` and lazy installs
  on first use, which Omarchy uses for its agent CLIs.
- Per-project pins. `~/Dev/h-cloud/mise.toml` can pin `talosctl`, `kubectl` and `flux` to the cluster's
  versions, which no package manager does today.

**Cannot do (or shouldn't):**

- GUI apps, casks, fonts, system services, kernel modules (`xpadneo-dkms`), PipeWire/LV2 plugins and
  libraries (`icu4c`, `nss`, `vips`, `libiscsi`).
- Things that hook into the OS:
  - Docker Desktop and the docker daemon.
  - keyd.
  - The login shell (`zsh`).
  - GNU userland on macOS (`coreutils`, `gnu-sed`). The registry's `coreutils` is uutils, not GNU.
  - yabai/skhd: launchd services and the sudoers rule.
- Tools that update themselves in place (oh-my-zsh, hermes), and Claude/Codex plugins (context-mode).
- Lua and neovim are better from brew/pacman. mise's lua plugin (vfox) builds Lua from source per version,
  and no project here needs pinned versions; the luarocks, busted and luacheck packages are built against the
  system Lua.

## Dotfiles: chezmoi in copy mode

chezmoi keeps a *source state* (the repo) and writes real files into `$HOME`. Copies remove the problems we
had with links:

- links dangling after a rebase or checkout;
- OpenDeck ignoring symlinked images;
- Quickshell crashing on a burst of link changes;
- omni pruning ignored files.

**Repository layout.** `.chezmoiroot` contains `home`, so chezmoi reads only `home/`, and the rest of the
repo (packages, mise, docs, tests) stays outside the source state. Files are named by chezmoi's
conventions:

```text
.chezmoiroot                       # "home"
home/
  .chezmoi.toml.tmpl               # asks for/derives the host once; sets .groups
  .chezmoiignore                   # template: skips files of groups this host doesn't have
  .chezmoiexternal.toml            # oh-my-zsh, tpm: git-repo externals, refreshPeriod 168h
  .chezmoiscripts/                 # run_onchange_ scripts (packages, mise, apm, host steps)
  .chezmoitemplates/               # shared fragments and host variants
  dot_zshrc.tmpl
  dot_config/git/config.tmpl       # topaz/towerr vs work Mac via {{ if }} or include
  dot_config/hypr/…
  dot_local/bin/executable_agent-run
  dot_local/bin/symlink_omp        # the few links we want stay links (omp → agent-run)
  private_dot_ssh/config
packages/brew/<group>.Brewfile
packages/arch/<group>.pacman, <group>.aur
mise/<group>.toml
```

**Hosts and groups.**

- `.chezmoi.toml.tmpl` maps `.chezmoi.hostname` to a list of groups, as today's `settings.json` hosts block
  does. It becomes `.groups` for every template.
- `.chezmoiignore` (a template) skips a group's files on hosts without that group. The mac-only packages
  are skipped by `.chezmoi.os`.
- Host variants (`git@topaz`, `zshrc@topaz`, `git@apm3ljhmvg7xgcf`) become one template each, or a template
  that includes the variant from `.chezmoitemplates/`.

**Partial directories.** chezmoi only writes the files in the source state and leaves everything else in a
directory alone (unless a directory is marked `exact_`). Untracked runtime state in `~/.claude`, `~/.codex`,
`~/.omp/agent`, `~/.config/omarchy` and `~/.config/hypr` stays untouched, and omni's `ignore` allow-lists
disappear.

**Daily use. This is the change from Stow:**

- Edits are no longer live in the repo. Either:
  - edit the source (`chezmoi edit ~/.config/hypr/bindings.lua`, or the repo file directly) and run
    `chezmoi apply`; or
  - edit in place and run `chezmoi re-add` to copy the change back (works for non-template files).
- `chezmoi status` / `chezmoi diff` show drift in both directions. `chezmoi merge` resolves a file changed on
  both sides.
- Apps that rewrite their own config (Zed settings, OpenDeck profiles, Omarchy `shell.json`):
  - `create_` files: chezmoi writes them once and then leaves them to the app; or
  - normal files that you `re-add` after changing them in the app.
- New machine: `chezmoi init --apply lkshrk/dotfiles` clones the repo, asks for nothing it can derive, writes
  files and runs the scripts. After a pull: `chezmoi update` (= git pull + apply).

**Secrets.** No secret goes into a file: MCP configs keep `${VAR}` references and `agent-run` supplies
values. chezmoi's `rbw` template function is available for files that need a value at write time (the LAN
CA, OBS settings), replacing those ad-hoc scripts.

## Proposed grouping

Today's 30 groups mix four axes:

- platform: `mac`, `desk-mac`, `gaming-mac`, `priv-mac`;
- purpose: `core`, `dev`, `dev-tooling`, `utils`;
- language: `go`, `lua`, `python`, `ts`;
- host names: `topaz`, `towerr`, `apm3ljhmvg7xgcf`.

Several also exist only because omni had one installer per tool (`prereqs`, `ai-plugins`, `omni`).

The new groups are by **role** and work on both OSes. The platform split happens inside each group: its
Brewfile holds the macOS entries, its pacman/AUR lists the Arch entries, and mise entries use
`os = [...]` only where a tool exists on one OS. Host-named groups go away. A tool only one host needs
goes into the role group that host has.

| Group | Contents (tools and dotfiles) |
|---|---|
| `base` | zsh + oh-my-zsh, tmux + tpm, neovim, vim, core CLIs (bat, eza, fd, ripgrep, jq, yq, fzf, …), git + gh + lazygit + delta, chezmoi, mise. Dotfiles: zsh, env (without secrets), git, tmux, nvim, vim, lazygit, gh |
| `personal` | rbw, pinentry, ssh config, knowledge-sync, the rbw envmaps and `agent-run` secrets, LAN CA. Kept off the work Mac |
| `dev` | lefthook, gitleaks, actionlint, shellcheck, bats, make/cmake/pkgconf, docker (Desktop / daemon), devcontainer, lazydocker, skopeo, yaml/markdown/bash linters and language servers, ttyd, vhs, ffmpeg, imagemagick, plantuml |
| `node` | node, bun, pnpm, TypeScript and its language server, pm2 |
| `python` | python, uv, poetry, basedpyright, pyright |
| `go` | go, task, golangci-lint, gopls, gomplate |
| `rust` | rust (rustup), rust-analyzer, cargo tools |
| `lua` | lua, luarocks, busted, luacheck, stylua, lua-language-server |
| `jvm` | java, maven, gradle, sqlcl |
| `infra` | Kubernetes, Talos, Flux, Helm, sops, OpenTofu, cilium, cnpg, cloudflared, homeassistant-cli, flux-local. Cluster-pinned versions live in `~/Dev/h-cloud/mise.toml` |
| `ai` | agent CLIs, rtk, codebase-memory-mcp, APM + `apm/ai-plugins`, context-mode plugins, obsidian-wiki. Dotfiles: claude, codex, omp, opencode |
| `desktop` | browsers, Zed, Obsidian, Signal, Ghostty/foot, fonts. Dotfiles: zed, ghostty |
| `media` | OBS (+ vkcapture), Stream Deck / OpenDeck, Wave Link / PipeWeaver, Discord/Equibop, Chatterino, Moonlight, Parsec, Plex, VLC/IINA. Dotfiles: opendeck, deck-icons, OBS templates |
| `gaming` | Steam, Battle.net, WowUp, xpadneo |
| `macos` | yabai, skhd-zig, hammerspoon, linearmouse, stats, mactop, mole, the-unarchiver, GNU coreutils/sed, mas, sleep-on-lock. Dotfiles: yabai, skhd, hammerspoon, linearmouse, cmux |
| `omarchy` | keyd, audio plugins (LSP, x42, DeepFilterNet), nfs/ntfs, hunspell, moshi-hook. Dotfiles: hypr, keyd, omarchy-shell, systemd-user, xkb, fcitx5, pipewire, wireplumber, gtk, local-bin, local-applications, nautilus, ha-doorbell |
| `apple-dev` | swiftformat, swiftlint, xcodegen, xcodebuildmcp |
| `work` | the work Mac's tools: AWS/Azure/OpenShift CLIs, Oracle JDK, DBeaver, Postman, Bruno, VS Code, git-credential-manager, Rectangle, AltTab, BetterDisplay, Telegram, Lightworks, Karakeep, … |

Hosts:

| Host | Groups |
|---|---|
| topaz | base personal dev node python go rust lua infra ai desktop media gaming macos apple-dev |
| towerr | base personal dev node python go rust lua infra ai desktop media gaming omarchy |
| work Mac | base dev node python jvm work |

Effects:

- **18 groups instead of 30**, and none is tied to a host or OS.
- A new Mac gets the same desktop as topaz by listing `desktop`; there's no separate `desk-mac`.
- `personal` keeps the vault, SSH config and agent secrets off the work Mac on purpose. Today that
  happens only because the work Mac doesn't list `secrets`/`priv`.
- The work Mac's 30-tool host group becomes `work` plus `jvm`. Its general CLIs (fzf, gum, jd,
  kubeconform, mkcert, …) move into `base`/`dev`/`infra`, where the other hosts get them too.
- topaz's host-only list folds in: prometheus and rclone → `infra`, duckdb and yt-dlp → `dev`, parsec →
  `media`, cliclick and duti → `macos`.

## Groups across the layers

A host's group list lives in `.chezmoi.toml.tmpl`, and each layer reads it:

- **dotfiles:** `.chezmoiignore` (above).
- **brew:** `run_onchange_before_10-brew.sh.tmpl` concatenates `packages/brew/<group>.Brewfile` for the
  host's groups and pipes them to `brew bundle --file=-`.
  - It embeds a hash of those files, so it reruns only when a list changes.
  - Drift: `brew bundle check` / `brew bundle cleanup`.
- **pacman / AUR:** `run_onchange_before_10-arch.sh.tmpl` does the same with `pacman -S --needed -` and
  `yay -S --needed -`.
  - Drift: `pacman -Qqen` / `-Qqem` compared with the lists.
- **mise:** chezmoi writes `~/.config/mise/conf.d/<group>.toml` only for the host's groups (they're ordinary
  managed files), and a `run_onchange_after_` script runs `mise install`.
  - On towerr, Omarchy's `/etc/mise/conf.d` loads first; ours only adds tools.
  - Its `locked_scopes = ["project", "global"]` setting needs checking first.
- **agents:** a `run_onchange_after_` script runs `apm install -g` when `apm/ai-plugins/apm.yml` changes.

`update.sh` stays as a short script for what chezmoi doesn't do on a schedule:

- macOS: `brew update && brew upgrade`.
- Arch: `yay -Syu`.
- Then: `mise upgrade --global`, `apm update -g`, `chezmoi update`, and a drift report: unlisted and
  missing packages, missing mise tools, `chezmoi status`.

## Tool inventory by stack, with the recommended installer

`mise` means the global mise config; a backend is named only when it isn't the registry default. Hosts follow
today's groups.

### Shell and core CLI (core, shell, utils)

- mise: bat, eza, fd, ripgrep, jq, yq, glow, just, fzf, gum, tealdeer (replaces tldr), yazi, witr, jd, duckdb,
  rclone, direnv, 7zip, tree-sitter (CLI), `npm:markdownlint-cli`
- brew + pacman: zsh, tmux, neovim, chezmoi, tree, wget, watch (pacman `procps-ng`), mosh, sshpass, bind,
  zstd, coreutils + gnu-sed (macOS only), wakeonlan (macOS), ouch (Arch)
- chezmoi `git-repo` externals: oh-my-zsh, tmux plugins (tpm)
- drop: thefuck (abandoned upstream; only distro patches keep it running), brew `tree-sitter` library
  (neovim needs only the CLI)

### Git and dev workflow (dev, dev-tooling, test-tooling)

- mise: gh, lazygit, delta, lefthook, gitleaks, actionlint, shellcheck, bats (`aqua:bats-core/bats-core`),
  lazydocker, yamlfmt, `pypi:yamllint`, `pypi:git-filter-repo`, `npm:@devcontainers/cli`, ttyd, vhs
- brew + pacman: docker (cask `docker-desktop` on macOS, `docker docker-compose docker-buildx` on Arch),
  skopeo, make, cmake, pkgconf, imagemagick, ffmpeg (AUR `ffmpeg-obs` on towerr), vips, plantuml
- brew (macOS): fswatch, git-credential-manager (work Mac)

### Node / TypeScript (ts, prereqs)

- mise: `node` (replaces nvm and `~/.nvm/default-packages`), `bun`, `pnpm`; npm ships with node
- mise `npm:`: typescript, typescript-language-server, yaml-language-server, bash-language-server, pyright,
  yaml-lint, pm2, ccundo
- drop: nvm, corepack, the bun/npm/pnpm duplicate providers for cmake, fswatch and lefthook

### Python (python)

- mise: `uv`; one global `python` 3.14 (`core:python`) for scripts that want `python3`; projects use
  `uv python` / `uv venv`
- mise `pypi:` (installed with uv): poetry, basedpyright, homeassistant-cli, flux-local, obsidian-wiki
- drop as global installs: pip, pipx, wheel, certifi, numpy, mlx. These are project dependencies; mlx goes
  into the project that uses it (`uv add mlx`)

### Go (go)

- mise: `go`, task (`go-task`), golangci-lint, gomplate, `go:golang.org/x/tools/gopls`

### Rust (ai-plugins today)

- mise: `rust` (`core:rust`, which runs rustup), rust-analyzer, `cargo:deepwiki-rs`
- drop: system `rustup`, the omni `cargo`/`rustup` script tools, the duplicate cargo provider for rbw

### Lua (lua)

- brew + pacman: lua, luarocks, busted, luacheck (packaged; mise would build lua from source)
- mise: stylua, lua-language-server

### Java and JVM (work Mac, topaz)

- mise: `java` (temurin 21), maven, gradle, sqlcl
- brew cask: oracle-jdk (if a licence requires it)

### Apple development (mac)

- brew: swiftformat, swiftlint, xcodegen, xcodebuildmcp, mas, cliclick, duti, flux-markdown

### Infrastructure, Kubernetes, cloud (infra)

- mise: kubectl, kubectx, krew, kustomize, helm, helmfile, flux2, cilium-cli,
  `aqua:cloudnative-pg/cloudnative-pg/kubectl-cnpg`, kubeconform, talosctl, sops, opentofu, terraform-ls,
  argo, mc (minio), mkcert, awscli, `github:` flate, `cargo:minijinja-cli` (or brew/AUR), `pypi:flux-local`
- pin in `~/Dev/h-cloud/mise.toml`: talosctl, kubectl, flux2, helm, cilium-cli, matching the cluster
- brew + pacman: cloudflared (a service on towerr), prometheus (topaz; promtool alone would be mise
  `aqua:prometheus/prometheus`)
- brew (work Mac): azure-cli, openshift-cli

### AI and agents (ai, ai-plugins)

- mise: claude, codex, oh-my-pi (`omp`), opencode, rtk, copilot-cli,
  `github:DeusData/codebase-memory-mcp` (needs an `asset_pattern`), `pypi:obsidian-wiki`
  - On towerr these come from Omarchy's mise layer (lazy, `auto_update = "4h"`). Our config adds only
    what Omarchy lacks, and the omni bun installs of codex and omp are removed. That bun omp is the copy
    that currently fails on Bun 1.4.3.
  - On the Macs, copy Omarchy's lines into `mise/ai.toml`.
- Claude and Codex plugins (context-mode): installed through their own plugin commands, from a chezmoi
  script (today's `context-mode-claude` and `context-mode-codex` scripts)
- APM fork: `uv tool install <wheel URL>#sha256=…` from a chezmoi script, then `apm install -g` against
  `apm/ai-plugins/apm.yml`. Upstream fails the secret test (see "APM: upstream tested").
- upstream installer: hermes (its own updater)
- drop: oh-my-codex (already removed), the bun `context-mode` CLI unless it's used directly

### Secrets

- brew + pacman: rbw (1.15.0 is now current everywhere, so the cargo pin can go), pinentry-mac (macOS)

### Desktop apps

- brew cask (macOS): brave-browser, helium, zed, obsidian, signal, discord, telegram, chatterino,
  moonlight, parsec, plex, obs, vlc, iina, ghostty, chatgpt-classic, openusage, linear, cmux, d-streamy,
  postman, bruno, dbeaver-community, visual-studio-code, lightworks, alt-tab, rectangle, betterdisplay,
  stats, the-unarchiver, mole, mactop, typewhisper, hammerspoon, linearmouse, battle-net, wowup-cf,
  elgato-stream-deck, elgato-wave-link, font-jetbrains-mono-nerd-font, karakeep, bam, sbx, depflush,
  osmium-tool
- brew taps (macOS): yabai (`asmvik/formulae/yabai`; the sudoers rule pins the binary's hash and must be
  refreshed after every upgrade, as `setup.sh` does), skhd-zig (`jackielii/tap/skhd-zig` +
  `skhd --install-service`)
- pacman / AUR (towerr): brave-bin, helium-browser-bin, zed, obsidian, signal-desktop, discord,
  equibop-bin, chatterino2-bin, moonlight-qt, plex-desktop, obs-studio-browser, opendeck, steam,
  mission-center, file-roller, wowup-cf-bin, ttf-jetbrains-mono-nerd-basic

### Omarchy system (omarchy)

- pacman: keyd, lsp-plugins-lv2, x42-plugins-lv2, deepfilternet-ladspa, nfs-utils, ntfsprogs, hunspell-de,
  hunspell-en_us, xpadneo-dkms, wimlib, mbedtls, uthash, cloudflared
- AUR: pipeweaver, coppwr, obs-vkcapture
- bootstrap script step: moshi-hook

### Host-only extras

- topaz (brew): libiscsi, vips, yt-dlp (or mise `github:yt-dlp/yt-dlp`), cmake, docker-buildx, fswatch,
  pkgconf, parsec, gradle, rclone, duckdb, prometheus, cliclick, duti
- work Mac (brew): awscli, azure-cli, fzf, gum, icu4c@76, jd, karakeep, kubeconform, maven, minio-mc,
  mkcert, nss, openjdk@21, openshift-cli, pinentry-mac, sblim-sfcc, tldr, wakeonlan, youtube-dl (replace
  with yt-dlp), alt-tab, betterdisplay, bruno, copilot-cli, dbeaver-community, git-credential-manager,
  lightworks, oracle-jdk, postman, rectangle, sqlcl, telegram, visual-studio-code. The CLIs among these
  move to mise like everywhere else.

## What omni does today that goes away

| omni feature | Replacement |
|---|---|
| `omni dots` (Stow links, ignore allow-lists, host packages) | chezmoi source state, `.chezmoiignore`, templates |
| Tool status / drift | `brew bundle check`, the `pacman -Qqe` diff, `mise ls --missing`, `chezmoi status` in `update.sh` |
| `omni doctor` checks | Mostly irrelevant. The MCP secret-literal check becomes a short script only if wanted |
| `omni agents env` | The envmaps in `env/secrets/` are the list; `agent-run` supplies them |
| Private APM copy with pin | `uv tool install` of the pinned fork wheel, from a chezmoi script |
| `agents.ignored`, dots `ignored` entries | Not needed: chezmoi touches only files in the source state |
| pacman conflict prompt (XXX-428) | Moot: `yay`/`pacman` run directly and interactively. Close the issue |
| Settings schema migrations (v26 → v27) | Gone |

## APM: upstream tested, fork stays

Tested 2026-11-14 with `tests/apm-secret-references.sh`:
- a throwaway `HOME`;
- fake values in the environment and no terminal;
- one HTTP header reference, one `Bearer ${VAR}` header and one stdio env reference, targeting Claude and
  Codex.

| | Claude (`~/.claude.json`) | Codex (`~/.codex/config.toml`) |
|---|---|---|
| upstream `apm-cli` 0.35.1 | **all three values written in plain text** | headers stay references; **stdio env value written in plain text** |
| fork 0.35.1+omni.2 | `${VAR}` everywhere | `env_http_headers`, `bearer_token_env_var`, `env_vars`; no values |

So the fork stays:

- Install it with `uv tool install` of the pinned wheel (version + sha256), from a chezmoi script.
- The wheel is published in the **omni** repo's releases (`apm-cli-0.35.1-omni.2`). Before omni is
  archived, republish it in `lkshrk/apm` and point the pin there. Archived repos keep their releases,
  but the wheel belongs with the fork.
- Offer the patches upstream as the user-scope counterpart of #3406. Rerun the test script against each
  new upstream release (`tests/apm-secret-references.sh 'apm-cli==<version>'`) and drop the fork once
  it passes.

## Migration order

1. **Freeze and snapshot.**
   - No new omni features.
   - On each host save `omni tools status`, `brew leaves` / `brew list --cask`, `pacman -Qqe`, `mise ls`,
     `uv tool list` and `bun pm ls -g` to diff against later.
2. **Move the fork wheel** to `lkshrk/apm` releases and update the pin.
3. **Convert the repo, on a branch:**
   - `chezmoi add` each managed file from towerr into `home/`, and turn host variants into templates;
   - generate the package lists and `mise/<group>.toml` from `tools.json` / `groups.json` with a one-off jq
     script, then hand-edit them along the inventory above.
4. **towerr first** (testable from this machine):
   - `chezmoi diff` must show only the intended changes;
   - remove the Stow links and apply chezmoi;
   - remove omni's bun copies of codex and omp;
   - check that the `pacman -Qqe` vs list diff is empty.
5. **topaz, then the work Mac.** `brew bundle check` should report nothing to do before omni goes.
6. **Remove omni:**
   - uninstall the binary and `~/.config/omni`;
   - delete `dotfiles/` and the `omni`/`omni-apm` packages;
   - replace `setup.sh` / `setup-omarchy.sh` with a short bootstrap (install Homebrew or `yay` + chezmoi,
     then `chezmoi init --apply`);
   - update the README and the vault.
7. **Deprecate omni:**
   - add a deprecation notice to the omni README pointing at the dotfiles repo's approach (chezmoi +
     mise + Brewfile/pacman lists + upstream APM);
   - archive the GitHub repository;
   - close the open omni issues in Linear (XXX-428 and others) with a reference to the notice.

## Decisions

Settled in review (2026-11-14):

- Dotfiles: **chezmoi with copies**, not Stow.
- mise groups: **conf.d files**, written by chezmoi per host.
- Global Python: **one mise `python`**, `uv` for projects.
- Agent CLIs on the Macs: **mise with `auto_update`**, as Omarchy does.
- APM: upstream tried; it writes secret values. **Keep the fork**, retest each upstream release.
- omni: **deprecation notice, then archive** (last step).
- Lua and neovim: **brew/pacman**.

- Grouping: **the 18 role-based groups** above.

Still open:

- Which app-written configs become `create_` (written once) vs managed and re-added.
- Whether `prometheus` on topaz is the server or only `promtool`.

## Checked (2026-11-14)

- **Omarchy's `locked_scopes`** only matters in strict lockfile mode (`locked = true`), which is off.
  Our `conf.d` tools need no lockfile entry. `mise lock --global` stays optional.
- **Release assets for mise's `github:` backend:**
  - flate (`home-operations/flate`): standard goreleaser names, auto-detected.
  - minijinja-cli: prebuilt binaries in `mitsuhiko/minijinja`; use `asset_pattern = "minijinja-cli-*"`
    instead of a cargo build.
  - codebase-memory-mcp: Linux has both `-portable` and plain tarballs plus `.mcpb` bundles; pin
    `asset_pattern = "codebase-memory-mcp-{os}-{arch}.tar.gz"`, as omni's recipe does.
  - Installing them through mise wasn't tried here (running downloaded binaries needs approval).
- **Codex's app-server daemon** has its own updater (`~/.codex/app-server-daemon/daemon-updater.*`) and
  installs its own releases under `~/.codex/packages/app-server-daemon/releases/`, independent of how the
  CLI was installed. mise manages only the CLI; the daemon keeps updating itself unless that updater is
  turned off. The documented switch isn't confirmed.
