#!/usr/bin/env bash
# setup-hermes.sh - bootstrap a Hermes workspace through its Omni host profile.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/setup-workspace.sh"

setup_workspace_main hermes
