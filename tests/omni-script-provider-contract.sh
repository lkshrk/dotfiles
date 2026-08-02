#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$repo_dir/dotfiles/omni/.config/omni/settings.json"
tools="$repo_dir/dotfiles/omni/.config/omni/settings.d/tools.json"

grep -Fq 'OMNI_MIN_VERSION="0.9.28"' "$repo_dir/setup.sh"
grep -Fq 'if ($i ~ /^v?[0-9]+' "$repo_dir/setup.sh"

jq -e '
  .version == 22
  and (.["$schema"] | endswith("/omni.settings.v22.schema.json"))
' "$settings" >/dev/null

jq -e '
  . as $root
  | [.tools | to_entries[] | .key as $name | .value.providers[]?
      | select(.provider == "script") | . + {logical_name: $name}] as $scripts
  | [$scripts[] | select(.recipe.type? == null)] as $custom
  | [
      "actionlint", "flux", "gitleaks", "glow", "helmfile", "kubectl-cnpg",
      "kubectx", "lazydocker", "lazygit", "opentofu", "sops", "talosctl",
      "ttyd", "vhs", "yamlfmt"
    ] as $verifiedRecipes
  | all($custom[];
      .options.install? != null
      and (.options.check? != null or .options.check_path? != null or .options.detect? != null))
  and all([
      "bun", "cargo", "coder", "deepwiki-rs", "golangci-lint", "gopls",
      "herdr-tether", "hermes", "just", "lazydocker", "nvm", "uv",
      "actionlint", "ffmpeg", "gitleaks", "glow", "lazygit", "ttyd", "vhs", "yamlfmt"
    ][];
      . as $name
      | any($scripts[];
          .logical_name == $name
          and (
            (.options.version? != null and .options.latest? != null)
            or (.recipe.type? == "github_release_asset" and .recipe.tag_name? == null)
          )))
  and all($verifiedRecipes[];
      . as $name
      | any($scripts[];
          .logical_name == $name
          and .recipe.type? == "github_release_asset"
          and .recipe.checksum_asset_pattern? != null
          and .recipe.tag_name? == null
          and .options.install? == null
          and .options.version? != null
          and .options.latest? == null))
  and all(["bun", "nvm", "oh-my-zsh"][];
      . as $name
      | all($scripts[] | select(.logical_name == $name); .options.uninstall? == null))
  and all($scripts[] | select(.recipe.type? == "github_release_asset");
      if .recipe.tag_name? == null then .recipe.installed_version? == null else true end)
  and all($scripts[];
      ((.options.install // "") | test("curl[^;|]*\\|[[:space:]]*(sh|bash)") | not))
  and all($scripts[];
      ((.options.uninstall // "") | test("rm[[:space:]][^;]*[[:space:]]\\$HOME") | not))
  and all(["bun", "cargo", "claude-code", "coder", "golangci-lint", "herdr", "hermes", "just"][];
      . as $name
      | any($scripts[];
          .logical_name == $name
          and ((.options.install // "") | contains("mktemp"))))
  and any($custom[];
      .logical_name == "kustomize"
      and ((.options.install // "") | contains("checksums.txt"))
      and ((.options.install // "") | contains("sha256sum"))
      and ((.options.install // "") | contains("mv -f")))
  and all(["ffmpeg"][];
      . as $name
      | any($scripts[];
          .logical_name == $name
          and ((.options.install // "") | contains("sha256sum"))
          and ((.options.install // "") | contains("mv -f"))))
  and any($custom[];
      .logical_name == "hermes"
      and ((.options.install // "") | contains("--non-interactive")))
  and any($custom[];
      .logical_name == "watch"
      and ((.options.latest // "") | contains("dnf repoquery") | not))
  and (($scripts | tostring) | contains("api.github.com") | not)
' "$tools" >/dev/null

while IFS= read -r command; do
  bash -n <<<"$command"
done < <(jq -r '
  .tools | to_entries[] | .value.providers[]?
  | select(.provider == "script")
  | .options
  | [.check?, .install?, .version?, .latest?, .upgrade?, .uninstall?][]
  | select(. != null)
' "$tools")

printf 'PASS: script providers satisfy lifecycle and safety contracts\n'
