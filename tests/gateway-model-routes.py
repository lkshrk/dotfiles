#!/usr/bin/env python3
"""No plugin agent or fallback may reference a disabled/missing provider model."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
directory = root / "dotfiles/opencode/.config/opencode"
config = json.loads((directory / "opencode.json").read_text())
available = {"litellm/" + model for model in config["providers"]["litellm"]["models"]}
assert config["model"] in available
checked = []


def check(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "model":
                assert item in available, f"Unroutable agent model: {item}"
                checked.append(item)
            else:
                check(item)
    elif isinstance(value, list):
        for item in value:
            check(item)


check(json.loads((directory / "oh-my-openagent.json").read_text()))
assert checked
print(f"PASS: {len(checked)} plugin agent/category/fallback routes use available gateway models")
