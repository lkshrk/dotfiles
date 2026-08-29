#!/usr/bin/env bash
set -euo pipefail

cfg="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dotfiles/omni/.config/omni/settings.json"

want_groups="ai core dev dev-tooling devbox-ai-plugins go infra lua prereqs python shell test-tooling ts"
got_groups=$(jq -r '.hosts.devbox | sort | join(" ")' "$cfg")
[ "$got_groups" = "$want_groups" ] || { echo "devbox host groups: got '$got_groups'"; exit 1; }

for bad in desk gaming mac priv utils omni; do
  if jq -e --arg g "$bad" '.hosts.devbox | index($g)' "$cfg" >/dev/null; then
    echo "devbox host must not include group $bad"; exit 1
  fi
done

groups_json="$(dirname "$cfg")/settings.d/groups.json"
[ "$(jq -r '.groups[] | select(.name=="agent-hermes") | .tools | join(" ")' "$groups_json")" = "camofox-browser hermes" ] || { echo "agent-hermes group wrong"; exit 1; }
[ "$(jq -r '.groups[] | select(.name=="agent-pilot") | .tools | join(" ")' "$groups_json")" = "pilot" ] || { echo "agent-pilot group wrong"; exit 1; }

tools_json="$(dirname "$cfg")/settings.d/tools.json"
jq -e '.tools.pilot.providers[0].provider == "script"' "$tools_json" >/dev/null || { echo "pilot tool missing"; exit 1; }
jq -e '
  .tools.docker.providers[] | select(.provider == "script")
  | .options.sources_format == "deb [arch={arch} signed-by={signed_by}] https://download.docker.com/linux/debian {suite} stable"
' "$tools_json" >/dev/null || { echo "docker apt source wrong"; exit 1; }
jq -e '
  ["busted", "lua-language-server", "luacheck", "luarocks", "stylua"]
  | all(.[]; . as $tool | any($tools[0].tools[$tool].providers[]; .provider != "brew"))
' --slurpfile tools "$tools_json" "$tools_json" >/dev/null || { echo "lua Linux providers missing"; exit 1; }
jq -e '
  ["deepwiki-rs", "herdr-tether"]
  | all(.[]; . as $tool
      | any($groups[0].groups[] | select(.name == "ai-plugins").tools[]; . == $tool)
      and all($groups[0].groups[] | select(.name == "devbox-ai-plugins").tools[]; . != $tool))
' --slurpfile groups "$groups_json" "$groups_json" >/dev/null || { echo "devbox-only cargo tool exclusion wrong"; exit 1; }

OMNI_HOSTNAME=devbox omni --config "$cfg" settings show >/dev/null

echo ok
