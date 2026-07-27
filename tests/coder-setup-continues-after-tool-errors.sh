#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/home/.local/bin"
touch "$test_dir/lan-ca.pem"

cat > "$test_dir/bin/uname" <<'EOF'
#!/bin/bash
[[ "${1:-}" == "-m" ]] && printf 'x86_64\n' || printf 'Linux\n'
EOF

cat > "$test_dir/bin/apt-get" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$test_dir/bin/sudo" <<'EOF'
#!/bin/bash
[[ "${1:-}" == "apt-get" ]] && exit 19
exit 0
EOF

cat > "$test_dir/bin/bash" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$test_dir/bin/nvim" <<'EOF'
#!/bin/bash
exit 1
EOF

cat > "$test_dir/bin/omni" <<'EOF'
#!/bin/bash
if [[ "$*" == *" tools sync "* ]]; then
  exit 23
fi
if [[ "$*" == *" --yes dots sync --use-repo" ]]; then
  touch "$CODER_SETUP_CONTINUED_MARKER"
fi
exit 0
EOF

cat > "$test_dir/home/.local/bin/codebase-memory-mcp" <<'EOF'
#!/bin/bash
exit 0
EOF

chmod +x "$test_dir/bin/"* "$test_dir/home/.local/bin/codebase-memory-mcp"

set +e
PATH="$test_dir/bin:/usr/bin:/bin" \
HOME="$test_dir/home" \
SHELL=/bin/zsh \
NVM_BIN='' \
NVM_DIR="$test_dir/home/.nvm" \
PNPM_HOME="$test_dir/home/.local/share/pnpm" \
OMNI_OTEL_CA_PATH="$test_dir/lan-ca.pem" \
CODER_OMNI_STACKS='' \
CODER_REPO_DIRS='' \
CODER_SETUP_CONTINUED_MARKER="$test_dir/continued" \
  /bin/bash "$repo_dir/setup-coder.sh" >"$test_dir/setup.log" 2>&1
status=$?
set -e

if [[ "$status" != 0 || ! -f "$test_dir/continued" ]]; then
  cat "$test_dir/setup.log" >&2
  exit 1
fi

printf 'PASS: Coder setup continues after optional tool sync errors\n'
