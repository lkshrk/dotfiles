# env

Shell-neutral environment layout for exported env, PATH, and secret injection.

This is a Stow-shaped package: `dotfiles/env/.config/env` is managed as
`~/.config/env` by Omni/Stow.

## Layers

- `profile.sh`: POSIX-safe entrypoint for exported base env and PATH.
- `lib/path.sh`: POSIX-safe path helpers.
- `os/<name>.sh`: OS-specific env and PATH facts.
- `machine/<name>.sh`: machine-specific env and PATH facts.
- `bin/rbw-env`: shell-neutral secret injection wrapper for agents, zsh
  wrappers, and one-off commands.
- `secrets/*.envmap`: rbw item to environment variable mappings by consumer.
- `tests/smoke.sh`: shell-mode checks before migration.
- `tests/linux-smoke.sh`: clean Linux env checks with fake HOME/NVM and
  optional rbw socket coverage.

## Stow/Omni Package Shape

- `zsh`: generic interactive zsh modules.
- `zsh@darwin`: macOS-only interactive zsh modules, including direnv, Docker
  completions, Homebrew-backed lazy tool loaders, rbw-backed CA lookup, and
  AI CLI secret wrappers.
- `zshenv` sources `profile.sh` directly (covers every zsh shell, login
  included). `zprofile` carries only login-only behavior, if any.

## Current Decisions

- No explicit npm path.
- zsh loads the same POSIX profile from `.zshenv`; login shells skip duplicate
  profile work through the profile load guard.
- Base env prepends the NVM default Node bin directory, so `#!/usr/bin/env node`
  CLIs work after Homebrew Node is unlinked.
- Interactive zsh auto-switches `.nvmrc` through the lightweight resolver and
  only loads full NVM when the fast installed-version path cannot resolve.
- No Corepack wrapper. Install `pnpm` as a normal global package in each NVM
  Node version that needs it.
- No `PNPM_HOME`; `pnpm` resolves from the active NVM Node bin directory.
- `NVM_DIR` is metadata only; loading nvm stays out of base env.
- Homebrew environment policy is macOS-specific. `os/darwin.sh` resolves and
  exports `HOMEBREW_PREFIX`; zsh lazy tool modules consume that variable
  instead of hardcoding Homebrew install paths.
- Homebrew OpenJDK is interactive-lazy through zsh wrappers; base env does not
  export `JAVA_HOME` or prepend Java bins.
- `KUBECONFIG` is machine-specific, not macOS-specific.
- `SSH_AUTH_SOCK` preserves existing agents by default. macOS points launchd
  shells at the rbw socket path; Linux adopts an existing rbw socket when one is
  present but does not require or invoke rbw.
- Maestro is project-local via direnv `.envrc`, not global env.
- Rust/Cargo is not included until Rust is actually installed.
- `~/.local/bin` wins over package-manager binaries.
- direnv shell hooks are explicit macOS interactive zsh overlay behavior, not base env.
- rbw secret injection is profile-based: `rbw-env <profile> -- <command>`.
