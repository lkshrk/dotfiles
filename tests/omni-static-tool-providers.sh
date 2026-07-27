#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$repo_dir/dotfiles/omni/.config/omni/settings.json"
tools="$repo_dir/dotfiles/omni/.config/omni/settings.d/tools.json"

jq -e '
  .host_settings.coder.provider_priority as $providers
  | ($providers | index("script")) < ($providers | index("apt"))
' "$settings" >/dev/null

jq -e '
  .tools.ffmpeg.providers[]
  | select(
      .provider == "script"
      and .bin == "ffmpeg"
      and .source == {"type":"github","owner":"BtbN","repo":"FFmpeg-Builds"}
      and .recipe.type == "github_release_asset"
      and .recipe.asset_pattern == "ffmpeg-master-latest-linux{arch}-gpl.tar.xz"
      and .recipe.binary_path == "bin/ffmpeg"
      and .recipe.tag_name == "latest"
    )
' "$tools" >/dev/null

jq -e '
  .tools.ttyd.providers[]
  | select(
      .provider == "script"
      and .bin == "ttyd"
      and .source == {"type":"github","owner":"tsl0922","repo":"ttyd"}
      and .recipe.type == "github_release_asset"
      and .recipe.asset_pattern == "ttyd.{arch}"
      and .recipe.tag_name == "1.7.7"
    )
' "$tools" >/dev/null

printf 'PASS: Coder uses static ffmpeg and ttyd release assets before apt\n'
