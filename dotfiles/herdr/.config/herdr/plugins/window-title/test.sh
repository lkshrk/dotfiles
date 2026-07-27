#!/bin/sh
set -eu

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
git -C "$test_root" init -q
git -C "$test_root" checkout -qb feature/title

mkdir "$test_root/bin"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$1 $2" in' \
  '  "pane current") printf '\''{"result":{"pane":{"cwd":"%s"}}}\n'\'' "$TEST_CWD" ;;' \
  '  "terminal title") printf "%s\n" "$4" > "$TEST_OUTPUT" ;;' \
  '  *) exit 1 ;;' \
  'esac' > "$test_root/bin/herdr"
chmod +x "$test_root/bin/herdr"

TEST_CWD=$test_root TEST_OUTPUT=$test_root/title HERDR_BIN_PATH=$test_root/bin/herdr \
  sh "$(dirname "$0")/set-title.sh"

test "$(cat "$test_root/title")" = "HERDR - < ${test_root##*/}[feature/title]"
