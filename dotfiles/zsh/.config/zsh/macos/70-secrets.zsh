# CA backed by Bitwarden via rbw; helpers come from ../68-rbw.zsh.
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

  _rbw_unlock_if_needed
  raw=$(rbw get --field username "$item" 2>/dev/null)
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
