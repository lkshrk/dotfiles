#!/usr/bin/env bash
# scripts/setup-coder-linux.sh - Coder-only Linux workspace prerequisites.

set -euo pipefail

install_lan_ca() {
  step "lan root CA"
  local target=/usr/local/share/ca-certificates/lan-ca.crt
  local src=
  local candidate
  for candidate in \
    "${OMNI_OTEL_CA_PATH:-}" \
    /etc/ssl/certs/lan-ca.pem \
    "$HOME/.local/share/certs/lan-ca.pem"
  do
    if [[ -n "$candidate" && -r "$candidate" ]]; then
      src="$candidate"
      break
    fi
  done

  if [[ -z "$src" ]]; then
    warn "lan CA not found; https to *.h-cloud.lan will fail until the pod provisions it"
    return
  fi

  if [[ -r "$target" ]] && cmp -s "$src" "$target"; then
    ok "lan CA already in system trust"
    return
  fi

  sudo install -m 0644 "$src" "$target" || {
    warn "lan CA copy failed; continuing setup"
    return 0
  }
  sudo update-ca-certificates >/dev/null || {
    warn "lan CA trust update failed; continuing setup"
    return 0
  }
  ok "lan CA installed into system trust (from $src)"
}

install_lan_ca
