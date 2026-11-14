#!/usr/bin/env bash
# The theme-set tmux hook writes the inline status palette from colors.toml and reloads running servers.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

render=$("$repo/scripts/render-home.sh" towerr "$tmp/render")
hook="$render/.config/omarchy/hooks/theme-set.d/20-tmux"
conf="$render/.config/tmux/tmux.conf"
[ -x "$hook" ] || fail "hook not rendered for towerr"
grep -qx 'source-file -q ~/.local/state/omarchy/current/theme/tmux.conf' "$conf" || fail "towerr tmux.conf does not source the theme palette"

tmpl="$repo/home/dot_config/tmux/tmux.conf.tmpl"
for host in topaz apm3ljhmvg7xgcf; do
  chezmoi --source "$repo" --override-data "{\"host\":\"$host\",\"chezmoi\":{\"os\":\"darwin\"}}" execute-template <"$tmpl" >"$tmp/$host.conf"
  grep -v -e '^# Omarchy theme palette' -e '^source-file -q ~/.local/state/omarchy' "$conf" | cmp -s - "$tmp/$host.conf" ||
    fail "$host tmux.conf differs from towerr beyond the Omarchy source line"
done

mkdir -p "$tmp/bin" "$tmp/theme"
cat >"$tmp/bin/omarchy-theme-color" <<'EOF'
#!/usr/bin/env bash
sed -n 's/^\([a-z_]*\) *= *"\(.*\)"$/\1\t\2/p' "$2"
EOF
cat >"$tmp/bin/tmux" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$TMUX_LOG"
case $1 in
  list-sessions) [ "${TMUX_RUNNING:-}" = 1 ] ;;
  show-options) [ -f "$TMUX_LOG.sourced" ] && echo '#[fg=#7aa2f7]x' || echo '#(/p/continuum_save.sh)#[fg=old]x' ;;
  source-file) touch "$TMUX_LOG.sourced" ;;
esac
EOF
chmod +x "$tmp/bin/omarchy-theme-color" "$tmp/bin/tmux"
cat >"$tmp/theme/colors.toml" <<'EOF'
accent = "#7aa2f7"
muted = "#414868"
background = "#1a1b26"
dark_background = "#16161e"
foreground = "#c0caf5"
dark_foreground = "#565f89"
EOF
export PATH="$tmp/bin:$PATH" OMARCHY_THEME_DIR="$tmp/theme" TMUX_LOG="$tmp/tmux.log"

bash "$hook"
sed -n '/^set -g status-style/,/^setw -g clock-mode-colour/p' "$conf" >"$tmp/inline"
cmp -s "$tmp/inline" "$tmp/theme/tmux.conf" || { diff "$tmp/inline" "$tmp/theme/tmux.conf" >&2; fail "generated palette differs from the inline Tokyo Night block"; }
[ "$(cat "$TMUX_LOG")" = "list-sessions" ] || fail "hook talked to tmux without a running server"

: >"$TMUX_LOG"
TMUX_RUNNING=1 bash "$hook"
expected="list-sessions
show-options -gv status-right
source-file $tmp/theme/tmux.conf
show-options -gv status-right
set-option -g status-right #(/p/continuum_save.sh)#[fg=#7aa2f7]x"
[ "$(cat "$TMUX_LOG")" = "$expected" ] || fail "unexpected tmux calls: $(cat "$TMUX_LOG")"

sed -i 's/^accent = .*/accent = "#abc"/' "$tmp/theme/colors.toml"
rm "$tmp/theme/tmux.conf"
bash "$hook"
[ ! -e "$tmp/theme/tmux.conf" ] || fail "a malformed colour still wrote a palette"
rm "$tmp/theme/colors.toml"
bash "$hook" || fail "hook fails without colors.toml"

printf 'PASS: tmux palette hook, Omarchy source line, darwin renders unchanged\n'
