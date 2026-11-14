#!/usr/bin/env bash
# OpenDeck profiles come from the repo but keep the live file's toggle state per key.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
dir="$repo/home/dot_config/opendeck/profiles/sd-EL18L1A02195"
render() {
  local t
  t=$(cat "$dir/modify_$1.json"; printf x)
  chezmoi --source "$repo" --override-data '{"host":"towerr"}' execute-template --with-stdin "${t%x}"
}

for p in Default Alt; do
  want="$repo/home/.chezmoitemplates/opendeck/$p.json"
  render "$p" < /dev/null > "$tmp/new.json"
  cmp -s "$tmp/new.json" "$want" || { echo "FAIL: $p without a live file is not the repo profile" >&2; exit 1; }
  render "$p" < "$want" > "$tmp/same.json"
  cmp -s "$tmp/same.json" "$want" || { echo "FAIL: $p rewrites an unchanged live file" >&2; exit 1; }
done

python3 -I - "$repo/home/.chezmoitemplates/opendeck/Default.json" "$tmp/live.json" <<'EOF'
import json, sys
p = json.load(open(sys.argv[1]))
toggle = p["keys"][0]
toggle["current_state"] = 1
toggle["children"][1]["current_state"] = 1
p["keys"][1]["current_state"] = 5
p["keys"][1]["settings"]["down"] = "stale-live-command"
toggle["action"]["name"] = "stale live name"
json.dump(p, open(sys.argv[2], "w"), indent=2)
EOF
render Default < "$tmp/live.json" > "$tmp/out.json"

python3 -I - "$repo/home/.chezmoitemplates/opendeck/Default.json" "$tmp/out.json" <<'EOF'
import json, sys
want, out = (json.load(open(f)) for f in sys.argv[1:])
toggle = out["keys"][0]
assert toggle["current_state"] == 1, "live toggle state was not kept"
assert toggle["children"][1]["current_state"] == 1, "live state of a child action was not kept"
assert toggle["children"][0]["current_state"] == 0
assert out["keys"][1]["current_state"] == 0, "an out-of-range live state was kept"
assert out["keys"][1]["settings"] == want["keys"][1]["settings"], "settings must come from the repo"
assert toggle["action"]["name"] == want["keys"][0]["action"]["name"], "actions must come from the repo"
toggle["current_state"] = toggle["children"][1]["current_state"] = 0
assert out == want, "fields other than current_state differ from the repo"
EOF

echo "PASS: OpenDeck profiles keep live toggle state; everything else comes from the repo"
