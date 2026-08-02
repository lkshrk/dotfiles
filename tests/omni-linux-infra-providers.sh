#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
groups="$repo_dir/dotfiles/omni/.config/omni/settings.d/groups.json"
tools="$repo_dir/dotfiles/omni/.config/omni/settings.d/tools.json"

jq -e --slurpfile groups "$groups" '
  . as $root
  | [$groups[0].groups[] | select(.name == "infra").tools[]] as $infra
  | all($infra[];
      . as $name
      | any($root.tools[$name].providers[]?;
        .provider == "script"
        or .provider == "uv"
        or .provider == "apt"
        or .provider == "apk"
        or .provider == "dnf"
        or .provider == "pacman"
        or .provider == "zypper"))
' "$tools" >/dev/null

jq -e --slurpfile groups "$groups" '
  . as $root
  | [$groups[0].groups[] | select(.name == "infra").tools[]] as $infra
  | all(
    $infra[] as $name
    | $root.tools[$name].providers[]?
    | select(.provider == "script" and .recipe.type? == "github_release_asset");
    .recipe.tag_name? == null
  )
  and all(["flux", "helmfile", "kubectl-cnpg", "kubectx", "opentofu", "sops", "talosctl"][];
    . as $name
    | any($root.tools[$name].providers[]?;
      .provider == "script"
      and .recipe.type? == "github_release_asset"
      and .recipe.checksum_asset_pattern? != null))
  and .tools.flux.git == "https://github.com/fluxcd/flux2"
  and any(.tools.helm.providers[]?;
    .provider == "script"
    and ((.options.install // "") | contains("mkdir -p"))
    and ((.options.install // "") | contains("mktemp"))
    and ((.options.install // "") | contains("openssl"))
    and ((.options.install // "") | contains("DESIRED_VERSION"))
    and ((.options.install // "") | contains("get-helm-4"))
    and ((.options.latest // "") | contains("refs/tags/v4.*")))
  and any(.tools.krew.providers[]?;
    .provider == "script"
    and ((.options.check // "") | contains("kubectl-krew"))
    and .options.uninstall? == null)
  and any(.tools["kubernetes-cli"].providers[]?;
    .provider == "script"
    and ((.options.install // "") | contains("stable-1.36.txt"))
    and ((.options.install // "") | contains("sha256")))
  and any(.tools.watch.providers[]?;
    .provider == "script"
    and .options.uninstall? == null
    and .options.version? != null
    and .options.latest? != null
    and ((.options.install // "") | contains("procps")))
  and all(["argo", "flux", "helm", "helmfile", "krew", "kubectl-cnpg", "kubectx", "kubernetes-cli", "kustomize", "opentofu", "sops", "talosctl"][];
    . as $name
    | any($root.tools[$name].providers[]?;
      .provider == "script"
      and (
        (.options.version? != null and .options.latest? != null)
        or (.recipe.type? == "github_release_asset" and .recipe.tag_name? == null)
      )))
  and all($infra[];
    . as $name
    | (($root.tools[$name] | tostring) | contains("api.github.com") | not))
' "$tools" >/dev/null

printf 'PASS: every infra tool has Linux install and update/version behavior\n'
