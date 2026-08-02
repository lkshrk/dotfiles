#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for script in setup-workspace.sh setup-coder.sh setup-hermes.sh scripts/setup-workspace-linux.sh; do
  [[ -f "$repo_dir/$script" ]] || {
    printf 'FAIL: missing %s\n' "$script" >&2
    exit 1
  }
  bash -n "$repo_dir/$script"
done

grep -Eq '^[[:space:]]+openssl([[:space:]\\]|$)' "$repo_dir/scripts/setup-workspace-linux.sh"
grep -Fq 'run_as_root()' "$repo_dir/scripts/setup-workspace-linux.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin"

cat > "$test_dir/bin/uname" <<'EOF'
#!/bin/bash
[[ "${1:-}" == "-m" ]] && printf 'x86_64\n' || printf 'Linux\n'
EOF

cat > "$test_dir/bin/sudo" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$test_dir/bin/bash" <<'EOF'
#!/bin/bash
case "${1:-}" in
  */install-omni-latest.sh|*/volatile-dots.sh) exit 0 ;;
  *) exec /bin/bash "$@" ;;
esac
EOF

cat > "$test_dir/bin/nvim" <<'EOF'
#!/bin/bash
exit 1
EOF

cat > "$test_dir/bin/omni" <<'EOF'
#!/bin/bash
printf '%s|%s\n' "${OMNI_HOSTNAME:-}" "$*" >> "$OMNI_ARGS_CAPTURE"
exit 0
EOF

chmod +x "$test_dir/bin/"*
touch "$test_dir/lan-ca.pem"

assert_before() {
  local capture="$1"
  local first second
  first="$(grep -nF "$2" "$capture" | head -1 | cut -d: -f1)"
  second="$(grep -nF "$3" "$capture" | tail -1 | cut -d: -f1)"
  (( first < second )) || {
    printf 'FAIL: expected %s before %s\n' "$2" "$3" >&2
    exit 1
  }
}

run_profile() {
  local profile="$1"
  local home="$test_dir/$profile-home"
  local capture="$test_dir/$profile-omni-args"

  mkdir -p "$home/.local/bin" "$home/.codex" "$home/.claude"
  printf 'model = "unchanged"\n' > "$home/.codex/config.toml"
  printf '{"marker":"unchanged"}\n' > "$home/.claude/settings.json"
  printf '{"marker":"unchanged"}\n' > "$home/.claude.json"
  cp "$home/.codex/config.toml" "$home/codex.before"
  cp "$home/.claude/settings.json" "$home/claude-settings.before"
  cp "$home/.claude.json" "$home/claude.before"
  printf '#!/bin/bash\nexit 0\n' > "$home/.local/bin/codebase-memory-mcp"
  chmod +x "$home/.local/bin/codebase-memory-mcp"

  HOME="$home" \
  PATH="$test_dir/bin:$PATH" \
  SHELL=/bin/zsh \
  NVM_BIN='' \
  NVM_DIR="$home/.nvm" \
  PNPM_HOME="$home/.local/share/pnpm" \
  OMNI_OTEL_CA_PATH="$test_dir/lan-ca.pem" \
  OMNI_ARGS_CAPTURE="$capture" \
  CODER_OMNI_STACKS=python \
  CODER_REPO_DIRS='' \
    /bin/bash "$repo_dir/setup-$profile.sh" >/dev/null 2>&1

  grep -Fq "$profile|--config " "$capture"
  grep -Fq ' tools sync shell' "$capture"
  grep -Fq ' tools sync prereqs' "$capture"
  grep -Fq ' tools sync --all' "$capture"
  grep -Fq ' dots sync --use-repo' "$capture"
  assert_before "$capture" ' tools sync shell' ' tools sync prereqs'
  assert_before "$capture" ' tools sync prereqs' ' tools sync --all'
  assert_before "$capture" ' tools sync --all' ' --yes dots sync --use-repo'

  if [[ "$profile" == coder ]]; then
    grep -Fq ' tools sync python' "$capture"
    grep -Fq ' agents plugins sync' "$capture"
    grep -Fq ' agents skills sync' "$capture"
    grep -Fq ' agents mcp sync' "$capture"
    assert_before "$capture" ' tools sync --all' ' tools sync python'
    assert_before "$capture" ' tools sync python' ' --yes dots sync --use-repo'
    assert_before "$capture" ' --yes dots sync --use-repo' ' agents plugins sync'
  else
    ! grep -Fq ' tools sync python' "$capture"
    ! grep -Fq ' agents ' "$capture"
    cmp -s "$home/codex.before" "$home/.codex/config.toml"
    cmp -s "$home/claude-settings.before" "$home/.claude/settings.json"
    cmp -s "$home/claude.before" "$home/.claude.json"
  fi
}

run_profile coder
run_profile hermes

printf 'PASS: workspace setup keeps Hermes free of Coder agent setup\n'
