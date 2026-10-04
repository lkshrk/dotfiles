#!/usr/bin/env python3
"""Bootstrap/reconcile must preserve runtime configs without writable git links."""
from pathlib import Path
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
setup = (repo / "setup.sh").read_text()
bootstrap = setup.split("omni_bootstrap() ", 1)[1].split(
    "# ─── Shared: generated shell completions", 1
)[0]
functions = (repo / "dotfiles/zsh/.config/zsh/60-functions.zsh").read_text()
omni_function = functions.split("_dotfiles_omni() {", 1)[1].split("\n}\n", 1)[0]

with tempfile.TemporaryDirectory() as scratch:
    root = Path(scratch)
    fixture = root / "repo"
    scripts = fixture / "scripts"
    scripts.mkdir(parents=True)
    for name in ("volatile-dots.sh", "volatile-dots.txt"):
        (scripts / name).write_bytes((repo / "scripts" / name).read_bytes())
    entries = [line for line in (scripts / "volatile-dots.txt").read_text().splitlines()
               if line and not line.startswith("#")]
    originals = {}
    for entry in entries:
        path = fixture / entry
        path.parent.mkdir(parents=True, exist_ok=True)
        originals[path] = f"portable template {entry}\n".encode()
        path.write_bytes(originals[path])
    binary = root / "bin"
    binary.mkdir()
    stub = binary / "omni"
    stub.write_text('''#!/usr/bin/env bash
set -eu
[[ " $* " == *" tools sync "* ]] && exit 0
while IFS= read -r entry; do
  [[ -n "$entry" && "$entry" != \\#* ]] || continue
  rel="${entry#dotfiles/}"
  target="$HOME/${rel#*/}"
  mkdir -p "$(dirname "$target")"
  ln -s "$DOTFILES_DIR/$entry" "$target"
  [[ "$STUB_STATUS" == 0 ]] || exit "$STUB_STATUS"
done < "$DOTFILES_DIR/scripts/volatile-dots.txt"
''')
    stub.chmod(0o755)
    for shell, body in (
        ("bash", "set -euo pipefail\nstep() { :; }\nomni_bootstrap() " + bootstrap + "\nomni_bootstrap\n"),
        ("zsh", "_dotfiles_omni() {" + omni_function + "\n}\n_dotfiles_omni reconcile\n"),
    ):
        for state in ("local", "linked", "fresh"):
            for status in (0, 42):
                home = root / f"{shell}-{state}-{status}"
                home.mkdir()
                expected = {}
                for entry in entries:
                    target = home / entry.split("/", 2)[2]
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if state == "local":
                        expected[target] = f"runtime state {entry}\n".encode()
                        target.write_bytes(expected[target])
                    elif state == "linked":
                        target.symlink_to(fixture / entry)
                        expected[target] = originals[fixture / entry]
                    elif status == 0 or entry == entries[0]:
                        expected[target] = originals[fixture / entry]
                env = dict(os.environ, HOME=str(home), REPO_DIR=str(fixture),
                           DOTFILES_DIR=str(fixture), OMNI_CONFIG_PATH="unused",
                           STUB_STATUS=str(status), PATH=f"{binary}:{os.environ['PATH']}")
                result = subprocess.run([shell, "-c", body], env=env, capture_output=True, text=True)
                assert result.returncode == status, (shell, state, status, result.stderr)
                for target, content in expected.items():
                    assert not target.is_symlink() and target.read_bytes() == content, target
                    assert not Path(str(target) + ".pre-sync").exists(), target
                    target.write_text("later runtime edit\n")
                assert all(path.read_bytes() == content for path, content in originals.items())
print("PASS: macOS bootstrap and dotsync preserve configs on success/failure; fresh files detach; git templates unchanged")
