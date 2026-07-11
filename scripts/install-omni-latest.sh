#!/usr/bin/env bash
# Install or upgrade omni from GitHub releases/latest.
set -euo pipefail

bin_dir="${DIR:-$HOME/.local/bin}"
mkdir -p "$bin_dir"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64*|arm64) arch=arm64 ;;
  *)
    echo "unsupported architecture for omni install: $arch" >&2
    exit 1
    ;;
esac

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
url="https://github.com/lkshrk/omni/releases/latest/download/omni_${os}_${arch}.tar.gz"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL "$url" -o "$tmpdir/omni.tar.gz"
tar -xzf "$tmpdir/omni.tar.gz" -C "$tmpdir" omni
install -Dm 755 "$tmpdir/omni" "$bin_dir/omni"