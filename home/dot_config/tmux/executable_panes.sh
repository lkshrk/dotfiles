#!/bin/sh
# join: every window of the current session becomes a pane of the current window, in a grid of at most 3 columns.
# split: every pane of the current window gets its own window, in pane order, right after it.
# toggle: split when the current window has several panes, join otherwise.
set -eu

target=$(tmux display -p '#{window_id}')

# Rows are filled as evenly as possible (5 panes: 3 + 2); tmux's own tiled layout stacks 6 panes as 3 rows of 2.
grid() {
  size=$(tmux display -p -t "$target" '#{window_width} #{window_height}')
  layout=$(tmux list-panes -t "$target" -F '#{pane_id}' | tr -d % | awk -v size="$size" '
    function part(total, count, i) { return int((total - count + 1) / count) + (i == count ? (total - count + 1) % count : 0) }
    function pane(w, h, x, y, id) { return w "x" h "," x "," y "," id }
    { id[NR] = $0 }
    END {
      split(size, s, " "); W = s[1]; H = s[2]; n = NR
      rows = int((n + 2) / 3); next_id = 1; y = 0; body = ""
      for (r = 1; r <= rows; r++) {
        k = int(n / rows) + (r <= n % rows ? 1 : 0)
        h = part(H, rows, r); x = 0; cells = ""
        for (c = 1; c <= k; c++) {
          w = part(W, k, c)
          cells = cells (c > 1 ? "," : "") pane(w, h, x, y, id[next_id++])
          x += w + 1
        }
        row = k == 1 ? cells : W "x" h ",0," y "{" cells "}"
        body = body (r > 1 ? "," : "") row
        y += h + 1
      }
      if (rows > 1) body = W "x" H ",0,0[" body "]"
      else if (k > 1) body = W "x" H ",0,0{" cells "}"
      sum = 0
      for (i = 1; i <= length(body); i++) {
        sum = int(sum / 2) + (sum % 2) * 32768 + ord[substr(body, i, 1)]
        sum %= 65536
      }
      printf "%04x,%s\n", sum, body
    }
    BEGIN { for (i = 32; i < 127; i++) ord[sprintf("%c", i)] = i }')
  tmux select-layout -t "$target" "$layout"
}

mode=${1:-}
if [ "$mode" = toggle ]; then
  if [ "$(tmux display -p '#{window_panes}')" -gt 1 ]; then mode=split; else mode=join; fi
fi

case "$mode" in
join)
  for window in $(tmux list-windows -F '#{window_id}'); do
    [ "$window" = "$target" ] && continue
    for pane in $(tmux list-panes -t "$window" -F '#{pane_id}'); do
      # Tiling after each join keeps room for the next pane; a full window refuses join-pane.
      tmux join-pane -d -s "$pane" -t "$target" && tmux select-layout -t "$target" tiled
    done
  done
  grid
  ;;
split)
  # Reversed, since each pane is inserted directly after the current window.
  for pane in $(tmux list-panes -t "$target" -F '#{pane_id}' | awk 'NR > 1 { p[NR] = $0 } END { for (i = NR; i > 1; i--) print p[i] }'); do
    tmux break-pane -d -a -s "$pane" -t "$target"
  done
  ;;
*)
  echo "usage: ${0##*/} join|split|toggle" >&2
  exit 2
  ;;
esac
