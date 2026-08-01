#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap="$REPO_DIR/scripts/bootstrap-agents.sh"
fake_home=$(mktemp -d)
fake_bin="$fake_home/bin"
ca_file="$fake_home/lan-ca.pem"
capture="$fake_home/node-extra-ca"
args_capture="$fake_home/omni-args"

cleanup() {
  rm -rf "$fake_home"
}
trap cleanup EXIT

mkdir -p "$fake_bin"
: > "$ca_file"
cat > "$fake_bin/omni" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' "${NODE_EXTRA_CA_CERTS:-}" >> "$OMNI_CA_CAPTURE"
printf '%s\n' "$*" >> "$OMNI_ARGS_CAPTURE"
EOF
chmod +x "$fake_bin/omni"

if HOME="$fake_home" PATH="$fake_home/empty-bin" REPO_DIR="$REPO_DIR" \
  /bin/bash "$bootstrap" >/dev/null 2>&1; then
  printf 'FAIL: missing omni did not fail agent bootstrap\n' >&2
  exit 1
fi

HOME="$fake_home" \
PATH="$fake_bin:$PATH" \
OMNI_CA_CAPTURE="$capture" \
OMNI_ARGS_CAPTURE="$args_capture" \
OMNI_CONFIG="$fake_home/missing-settings.json" \
OMNI_OTEL_CA_PATH="$ca_file" \
NODE_EXTRA_CA_CERTS='' \
bash "$bootstrap" >/dev/null

[[ "$(sort -u "$capture")" == "$ca_file" ]] || {
  printf 'FAIL: agent bootstrap did not propagate NODE_EXTRA_CA_CERTS\n' >&2
  exit 1
}
for component in plugins skills mcp; do
  grep -Fq -- "--yes agents $component sync" "$args_capture"
done
if grep -qw restore "$args_capture"; then
  printf 'FAIL: agent bootstrap still invokes deprecated restore commands\n' >&2
  exit 1
fi

printf 'PASS: agent bootstrap propagates the Node CA and uses sync commands\n'
