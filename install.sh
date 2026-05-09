#!/usr/bin/env bash
# Compatibility shim. New installs should run ./setup.sh directly.

set -euo pipefail

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup.sh" "$@"
