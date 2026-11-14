# Tool caches under one directory, a Btrfs subvolume on Linux so snapshots skip it.

export DEV_CACHE_HOME="${DEV_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/dev}"

export GOCACHE="${GOCACHE:-$DEV_CACHE_HOME/go/build}"
export GOMODCACHE="${GOMODCACHE:-$DEV_CACHE_HOME/go/mod}"
export GOLANGCI_LINT_CACHE="${GOLANGCI_LINT_CACHE:-$DEV_CACHE_HOME/golangci-lint}"
export npm_config_cache="${npm_config_cache:-$DEV_CACHE_HOME/npm}"
export pnpm_config_store_dir="${pnpm_config_store_dir:-$DEV_CACHE_HOME/pnpm/store}"
export pnpm_config_cache_dir="${pnpm_config_cache_dir:-$DEV_CACHE_HOME/pnpm/cache}"
export DENO_DIR="${DENO_DIR:-$DEV_CACHE_HOME/deno}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$DEV_CACHE_HOME/uv}"
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-$DEV_CACHE_HOME/pip}"
export POETRY_CACHE_DIR="${POETRY_CACHE_DIR:-$DEV_CACHE_HOME/poetry}"
# Cargo intermediates leave target/, which keeps only final artifacts; on Linux ~/.cargo links into DEV_CACHE_HOME.
[ -n "${CARGO_BUILD_BUILD_DIR:-}" ] || export CARGO_BUILD_BUILD_DIR='{cargo-cache-home}/build/{workspace-path-hash}'
export CPM_SOURCE_CACHE="${CPM_SOURCE_CACHE:-$DEV_CACHE_HOME/cpm}"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-$DEV_CACHE_HOME/playwright}"
export HELM_CACHE_HOME="${HELM_CACHE_HOME:-$DEV_CACHE_HOME/helm}"
export CCACHE_DIR="${CCACHE_DIR:-$DEV_CACHE_HOME/ccache}"
export SCCACHE_DIR="${SCCACHE_DIR:-$DEV_CACHE_HOME/sccache}"
