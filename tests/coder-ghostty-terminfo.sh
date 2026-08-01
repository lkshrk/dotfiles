#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
linux_setup="$repo_dir/scripts/setup-coder-linux.sh"
terminfo_source="$repo_dir/assets/terminfo/xterm-ghostty.terminfo"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

real_tic="$(command -v tic)"
real_infocmp="$(command -v infocmp)"
mkdir -p "$test_dir/bin" "$test_dir/home"

cat > "$test_dir/bin/infocmp" <<'EOF'
#!/usr/bin/env sh
if [ "${TERMINFO:-}" = "$HOME/.terminfo" ]; then
  exec "$REAL_INFOCMP" "$@"
fi
exit 1
EOF

cat > "$test_dir/bin/tic" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' "$*" > "$TIC_CAPTURE"
exec "$REAL_TIC" "$@"
EOF

chmod +x "$test_dir/bin/infocmp" "$test_dir/bin/tic"

# shellcheck source=/dev/null
source <(sed -n '/^install_ghostty_terminfo()/,/^}/p' "$linux_setup")
step() { :; }
ok() { :; }
warn() { :; }

HOME="$test_dir/home" \
PATH="$test_dir/bin:$PATH" \
REPO_DIR="$repo_dir" \
REAL_TIC="$real_tic" \
REAL_INFOCMP="$real_infocmp" \
TIC_CAPTURE="$test_dir/tic-args" \
  install_ghostty_terminfo

grep -Fq -- "-x -o $test_dir/home/.terminfo $terminfo_source" "$test_dir/tic-args"
TERMINFO="$test_dir/home/.terminfo" "$real_infocmp" -x xterm-ghostty >/dev/null

printf 'PASS: Coder installs Ghostty terminfo into the user database\n'
