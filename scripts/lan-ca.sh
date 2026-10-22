#!/usr/bin/env bash
# Writes the vault's LAN root CA to ~/.local/share/certs/lan-ca.pem; on Linux also trusts it system-wide.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib/setup-common.sh"

item="${1:-root-CA}"
lan_ca="$HOME/.local/share/certs/lan-ca.pem"
anchor=/etc/ca-certificates/trust-source/anchors/lan-ca.crt

rbw unlocked >/dev/null 2>&1 || die "rbw is locked; unlock it and rerun $0"
raw="$(rbw get --field username "$item" 2>/dev/null)" && [[ -n "$raw" ]] \
  || die "could not read $item from the vault; LAN hosts (litellm) will fail TLS"

body="$(sed -e 's/-----BEGIN CERTIFICATE-----//' -e 's/-----END CERTIFICATE-----//' <<<"$raw" | tr -d '[:space:]')"
mkdir -p "${lan_ca%/*}"
tmp="$(mktemp "$lan_ca.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
{ echo "-----BEGIN CERTIFICATE-----"; fold -w64 <<<"$body"; echo "-----END CERTIFICATE-----"; } >"$tmp"
openssl x509 -in "$tmp" -noout 2>/dev/null \
  || die "vault item $item is not a valid certificate; LAN hosts (litellm) will fail TLS"
chmod 0644 "$tmp"
mv "$tmp" "$lan_ca"
ok "LAN root CA written to ${lan_ca/#"$HOME"/\~}"

[[ "$(uname -s)" == Linux ]] || exit 0
if ! cmp -s "$lan_ca" "$anchor"; then
  sudo install -Dm644 "$lan_ca" "$anchor"
  sudo update-ca-trust
fi
ok "LAN root CA is trusted system-wide"
