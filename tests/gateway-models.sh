#!/bin/sh
# Renders towerr's opencode, zed and omp configs and checks them against home/.chezmoidata/models.yaml.
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

render() { chezmoi --source "$repo" --override-data '{"host":"towerr"}' "$@"; }
render execute-template '{{ toJson .gateway }}' > "$tmp/gateway.json"
home=$("$repo/scripts/render-home.sh" towerr "$tmp/render")
modify=$(cat "$repo/home/dot_config/zed/modify_settings.json")
cat > "$tmp/live.json" <<'EOF'
{
  // a comment Zed would keep but this script drops
  "vim_mode": false,
  "agent": {
    "default_model": { "provider": "Lite-LLM-OpenAI", "model": "openai/gpt-sol" },
    "commit_message_model": { "provider": "Lite-LLM-Anthropic", "model": "claude-haiku" },
  },
  "language_models": { "openai_compatible": { "Lite-LLM-OpenAI": { "api_url": "https://old.example/v1", "available_models": [{ "name": "stale" }] } } },
}
EOF
render execute-template --with-stdin "$modify" < "$tmp/live.json" > "$tmp/zed-live.json"

python3 -I - "$tmp/gateway.json" "$home" "$tmp/zed-live.json" <<'EOF'
import json, re, sys
gw = json.load(open(sys.argv[1]))
home = sys.argv[2]
errors = []
def check(cond, msg):
    if not cond:
        errors.append(msg)
def jsonc(path):
    text = open(path).read()
    text = re.sub(r'("(?:[^"\\]|\\.)*")|//[^\n]*', lambda m: m.group(1) or "", text)
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))

models = {m["id"]: m for m in gw["models"]}
check(len(models) == len(gw["models"]), "duplicate model ids")

oc = jsonc(f"{home}/.config/opencode/opencode.jsonc")
p = oc["providers"]["local-agents"]
check(p["settings"]["baseURL"] == gw["url"] + "/v1", "opencode baseURL")
check(set(p["models"]) == set(models), f"opencode ids differ: {sorted(set(p['models']) ^ set(models))}")
for i, m in p["models"].items():
    if i in models:
        check(m["limit"] == {"context": models[i]["context"], "output": models[i]["output"]}, f"opencode {i} limits")
for ref in (oc["model"].split("#")[0], oc["agents"]["title"]["model"]):
    check(ref.split("/", 1)[1] in models, f"opencode references undeclared {ref}")

def zed_check(label, z):
    lm = z["language_models"]
    a = lm["anthropic_compatible"]["Lite-LLM-Anthropic"]
    o = lm["openai_compatible"]["Lite-LLM-OpenAI"]
    check(a["api_url"] == gw["url"] and o["api_url"] == gw["url"] + "/v1", f"zed {label} api_url")
    got = {m["name"]: m for m in a["available_models"] + o["available_models"]}
    check(set(got) == set(models), f"zed {label} ids differ: {sorted(set(got) ^ set(models))}")
    check({m["name"] for m in a["available_models"]} == {i for i, m in models.items() if m["family"] == "anthropic"}, f"zed {label} anthropic split")
    for i, m in got.items():
        if i in models:
            check((m["max_tokens"], m["max_output_tokens"]) == (models[i]["context"], models[i]["output"]), f"zed {label} {i} limits")
    for k, v in z["agent"].items():
        if k.endswith("_model"):
            check(v["model"] in models, f"zed {label} agent.{k} references {v['model']}")
    return z

zed_check("new file", json.load(open(f"{home}/.config/zed/settings.json")))
live = zed_check("existing file", json.load(open(sys.argv[3])))
check(live["vim_mode"] is False, "zed modify dropped an unrelated setting")
check(live["agent"]["default_model"]["model"] == "openai/gpt-sol", "zed modify replaced a valid model choice")
check(live["agent"]["commit_message_model"]["model"] == "anthropic/claude-haiku", "zed modify kept a stale model")

omp = open(f"{home}/.omp/agent/models.yml").read()
overrides = set(re.findall(r"^      (\S+):$", omp, re.M))
check(overrides == {i for i, m in models.items() if m["family"] == "anthropic"}, f"omp modelOverrides: {sorted(overrides)}")
for ref in re.findall(r"local-agents/(\S+?)(?::\w+)?$", open(f"{home}/.omp/agent/config.yml").read(), re.M):
    check(ref in models, f"omp role references undeclared {ref}")

if errors:
    print("\n".join("FAIL: " + e for e in errors), file=sys.stderr)
    sys.exit(1)
print(f"PASS: {len(models)} gateway models match opencode, zed and omp")
EOF
