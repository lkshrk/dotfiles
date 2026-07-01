# Lazy manual secret helpers backed by Bitwarden via rbw.
# Command wrappers use ~/.config/env/bin/rbw-env instead.
_rbw_available() {
  (( $+commands[rbw] )) || return 1
  rbw config show >/dev/null 2>&1
}

_rbw_can_prompt() {
  [[ -o interactive && -t 0 && -t 1 && -r /dev/tty ]]
}

_rbw_unlock_if_needed() {
  _rbw_available || return 1
  rbw unlocked >/dev/null 2>&1 && return 0

  if _rbw_can_prompt; then
    print -u2 "rbw: vault locked; unlocking"
    rbw unlock </dev/tty >/dev/tty 2>/dev/tty && rbw unlocked >/dev/null 2>&1
    return
  fi

  return 1
}

_rbw_ssh_auth_sock() {
  local lib="${ENV_DIR:-${ENV_NEXT_DIR:-$HOME/.config/env}}/lib/rbw-sock.sh"
  [[ -r "$lib" ]] || return 1
  source "$lib"
  env_next_rbw_sock_darwin
}

_rbw_fix_ssh_auth_sock() {
  case "${SSH_AUTH_SOCK:-}" in
    ''|/var/run/com.apple.launchd.*/Listeners)
      local rbw_sock
      rbw_sock=$(_rbw_ssh_auth_sock) || return 1
      export SSH_AUTH_SOCK="$rbw_sock"
      ;;
  esac
}

_rbw_ssh_agent_available() {
  _rbw_fix_ssh_auth_sock || return 1
  [[ -n "${SSH_AUTH_SOCK:-}" ]] || return 1
  [[ -S "$SSH_AUTH_SOCK" ]] || return 1
  ssh-add -l >/dev/null 2>&1
}

_rbw_ssh_agent_ready() {
  _rbw_fix_ssh_auth_sock || {
    print -u2 "rbw: could not determine rbw SSH agent socket"
    return 1
  }

  _rbw_ssh_agent_available && return 0

  _rbw_available || {
    print -u2 "rbw: not available or not configured; git over SSH cannot use the rbw SSH agent"
    return 1
  }

  if ! _rbw_can_prompt; then
    print -u2 "rbw: vault locked; git over SSH needs the rbw SSH agent"
    print -u2 "rbw: run 'rbw unlock' in an interactive shell, then retry"
    return 1
  fi

  _rbw_unlock_if_needed || return 1

  [[ -n "${SSH_AUTH_SOCK:-}" ]] || {
    print -u2 "rbw: SSH_AUTH_SOCK is not set; git over SSH cannot use the rbw SSH agent"
    return 1
  }

  [[ -S "$SSH_AUTH_SOCK" ]] || {
    print -u2 "rbw: SSH_AUTH_SOCK does not point to a socket: $SSH_AUTH_SOCK"
    return 1
  }

  ssh-add -l >/dev/null 2>&1 || {
    print -u2 "rbw: could not talk to SSH agent at $SSH_AUTH_SOCK"
    print -u2 "rbw: run 'rbw unlock' in an interactive shell, then retry"
    return 1
  }
}

_rbw_get_or_unlock() {
  local item=$1 val
  _rbw_unlock_if_needed || return 1
  val=$(rbw get "$item" 2>/dev/null) || return 1

  [[ -n $val ]] || return 1
  print -n "$val"
}

_lazy_secret() {
  local var=$1 item=$2
  if [[ -z ${(P)var} ]]; then
    local val
    val=$(_rbw_get_or_unlock "$item") || {
      print -u2 "rbw: could not retrieve '$item' for $var; vault may be locked, item may be missing, or rbw auth may need attention"
      return 1
    }
    typeset -gx "$var=$val"
  fi
}

hf_key()       { _lazy_secret HF_TOKEN          hf-token; }
context7_key() { _lazy_secret CONTEXT7_API_KEY  context7-api-key; }
pocket_id_key()   { _lazy_secret POCKET_ID_API_KEY    pocket-id-api-key; }
h_cloud_age_key() { _lazy_secret SOPS_AGE_KEY    h-cloud-age-key; }

_valid_cert_file() {
  [[ -r $1 ]] && openssl x509 -in "$1" -noout >/dev/null 2>&1
}

_root_ca_cert_file() {
  local item=${1:-root-CA}
  local out=${2:-$HOME/.local/share/certs/lan-ca.pem}
  local raw tmp

  if _valid_cert_file "$out"; then
    print -r -- "$out"
    return 0
  fi

  _rbw_unlock_if_needed || raw=
  [[ -n ${raw:-} ]] || raw=$(rbw get --field username "$item" 2>/dev/null)
  if [[ -z $raw ]]; then
    print -u2 "rbw: could not retrieve public cert from '$item' and no valid cached cert exists at $out"
    return 1
  fi

  mkdir -p "${out:h}" || return 1
  tmp=$(mktemp "${out}.tmp.XXXXXX") || return 1

  ROOT_CA_RAW="$raw" python3 - "$tmp" <<'PY'
import os
import pathlib
import re
import sys
import textwrap

out = pathlib.Path(sys.argv[1])
raw = os.environ.get("ROOT_CA_RAW", "")
match = re.search(
    r"-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----",
    raw,
    re.S,
)
if not match:
    raise SystemExit("missing PEM certificate markers")

body = re.sub(r"\s+", "", match.group(1))
out.write_text(
    "-----BEGIN CERTIFICATE-----\n"
    + "\n".join(textwrap.wrap(body, 64))
    + "\n-----END CERTIFICATE-----\n"
)
PY

  if ! _valid_cert_file "$tmp"; then
    rm -f "$tmp"
    print -u2 "rbw: '$item' username field is not a valid certificate"
    return 1
  fi

  mv "$tmp" "$out" && chmod 0644 "$out" || return 1
  print -r -- "$out"
}

# Mac overrides for the shared OTEL base (65-ai-otel.zsh): resolve the lan CA
# from the vault instead of a pod-provisioned file, and require it: a missing
# CA aborts the launch so telemetry is never silently dropped.
OMNI_OTEL_REQUIRE_CA=1
_omni_otel_ca() { _root_ca_cert_file }
