# sops + age helpers — encrypt/decrypt files with a default age key.
# Requires: sops, age (brew install sops age)
(( $+commands[sops] )) || return 0

# Default age key location (XDG standard)
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

# Generate an age keypair if none exists yet.
sops-init() {
  if [[ -f $SOPS_AGE_KEY_FILE ]]; then
    print -P "%F{yellow}age key already exists:%f $SOPS_AGE_KEY_FILE"
    grep '^# public key:' "$SOPS_AGE_KEY_FILE"
    return 0
  fi

  if ! (( $+commands[age-keygen] )); then
    print -u2 "age not installed — run: brew install age"
    return 1
  fi

  mkdir -p "${SOPS_AGE_KEY_FILE:h}"
  age-keygen -o "$SOPS_AGE_KEY_FILE" 2>&1
  chmod 600 "$SOPS_AGE_KEY_FILE"
  print -P "%F{green}age key created:%f $SOPS_AGE_KEY_FILE"
}

# Get the public key from the default age key.
sops-pubkey() {
  if [[ ! -f $SOPS_AGE_KEY_FILE ]]; then
    print -u2 "no age key found — run: sops-init"
    return 1
  fi
  grep '^# public key:' "$SOPS_AGE_KEY_FILE" | cut -d' ' -f4
}

# Encrypt a file in-place with sops + age.
# Usage: sops-encrypt <file> [extra sops flags...]
sops-encrypt() {
  local file=$1; shift
  [[ -n $file ]] || { print -u2 "usage: sops-encrypt <file> [flags...]"; return 2; }
  [[ -f $file ]] || { print -u2 "file not found: $file"; return 1; }

  local pubkey
  pubkey=$(sops-pubkey) || return 1

  sops encrypt --age "$pubkey" --in-place "$@" "$file"
}

# Decrypt a file in-place with sops + age.
# Usage: sops-decrypt <file> [extra sops flags...]
sops-decrypt() {
  local file=$1; shift
  [[ -n $file ]] || { print -u2 "usage: sops-decrypt <file> [flags...]"; return 2; }
  [[ -f $file ]] || { print -u2 "file not found: $file"; return 1; }

  sops decrypt --in-place "$@" "$file"
}

# Decrypt to stdout (no file modification).
# Usage: sops-cat <file>
sops-cat() {
  local file=$1
  [[ -n $file ]] || { print -u2 "usage: sops-cat <file>"; return 2; }
  [[ -f $file ]] || { print -u2 "file not found: $file"; return 1; }

  sops decrypt "$file"
}

# Edit an encrypted file (decrypt, open in $EDITOR, re-encrypt).
# Usage: sops-edit <file>
sops-edit() {
  local file=$1
  [[ -n $file ]] || { print -u2 "usage: sops-edit <file>"; return 2; }
  [[ -f $file ]] || { print -u2 "file not found: $file"; return 1; }

  sops edit "$file"
}
