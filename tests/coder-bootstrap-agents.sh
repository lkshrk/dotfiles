#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fake_home=$(mktemp -d)
fake_bin="$fake_home/bin"
ca_file="$fake_home/lan-ca.pem"
capture="$fake_home/node-extra-ca"

cleanup() {
  rm -rf "$fake_home"
}
trap cleanup EXIT

mkdir -p "$fake_bin"
: > "$ca_file"
cat > "$fake_bin/omni" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' "${NODE_EXTRA_CA_CERTS:-}" >> "$OMNI_CA_CAPTURE"
EOF
chmod +x "$fake_bin/omni"

HOME="$fake_home" \
PATH="$fake_bin:$PATH" \
OMNI_CA_CAPTURE="$capture" \
OMNI_CONFIG="$fake_home/missing-settings.json" \
OMNI_OTEL_CA_PATH="$ca_file" \
NODE_EXTRA_CA_CERTS='' \
bash "$REPO_DIR/scripts/bootstrap-agents.sh" >/dev/null

[[ "$(sort -u "$capture")" == "$ca_file" ]] || {
  printf 'FAIL: agent bootstrap did not propagate NODE_EXTRA_CA_CERTS\n' >&2
  exit 1
}

printf 'PASS: agent bootstrap propagates the Node CA\n'
