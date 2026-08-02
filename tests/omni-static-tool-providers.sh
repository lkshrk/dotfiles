#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$repo_dir/dotfiles/omni/.config/omni/settings.json"
tools="$repo_dir/dotfiles/omni/.config/omni/settings.d/tools.json"

jq -e '
  .host_settings.coder.provider_priority as $providers
  | ($providers | index("script")) as $script
  | ($providers | index("apt")) as $apt
  | $script != null and $apt != null and $script < $apt
' "$settings" >/dev/null

jq -e '
  .tools.ffmpeg.providers[]
  | select(
      .provider == "script"
      and .bin == "ffmpeg"
      and ((.options.install // "") | contains("BtbN/FFmpeg-Builds"))
      and ((.options.install // "") | contains("checksums.sha256"))
      and ((.options.install // "") | contains("autobuild-"))
      and .options.version? != null
      and .options.latest? != null
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
      and .recipe.checksum_asset_pattern == "SHA256SUMS"
      and .recipe.tag_name? == null
    )
' "$tools" >/dev/null

jq -e '
  .tools.pipx.providers[]
  | select(.provider == "apt" and .package == "pipx")
' "$tools" >/dev/null

jq -e '
  .tools["python@3.14"].providers[]
  | select(
      .provider == "script"
      and .bin == "python3.14"
      and ((.options.install // "") | contains("python install 3.14"))
      and ((.options.check // "") | contains("python find 3.14"))
      and .options.version? != null
    )
' "$tools" >/dev/null

printf 'PASS: Coder has static and Linux tool-provider fallbacks\n'
