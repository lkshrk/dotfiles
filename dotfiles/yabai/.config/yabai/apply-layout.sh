#!/usr/bin/env bash
set -euo pipefail

# ── Display detection ─────────────────────────────────────────────────────────
PRIMARY_DISPLAY="$(
  yabai -m query --displays | jq -r '[.[] | select(.frame.w > .frame.h)] | sort_by(.frame.w) | last | .index'
)"
SECONDARY_DISPLAY="$(
  yabai -m query --displays | jq -r '[.[] | select(.frame.h > .frame.w)] | sort_by(.frame.h) | last | .index'
)"

read -r PX PY PW PH < <(
  yabai -m query --displays \
    | jq -r --argjson d "$PRIMARY_DISPLAY" '
        .[] | select(.index == $d) | "\(.frame.x|floor) \(.frame.y|floor) \(.frame.w|floor) \(.frame.h|floor)"'
)

read -r SX SY SW SH < <(
  yabai -m query --displays \
    | jq -r --argjson d "$SECONDARY_DISPLAY" '
        .[] | select(.index == $d) | "\(.frame.x|floor) \(.frame.y|floor) \(.frame.w|floor) \(.frame.h|floor)"'
)

# ── Spaces ────────────────────────────────────────────────────────────────────
SP_MAIN=1
SP_STACK=2
SP_MOONLIGHT=3
SP_REMOTE=4
SP_COMMS=5
SP_STREAM=6

# ── Portrait dimensions ──────────────────────────────────────────────────────
S_THIRD_H=$(( SH / 3 ))
S_SEVEN15_H=$(( SH * 7 / 15 ))
S_SEVEN15_Y=$(( SY + SH - S_SEVEN15_H ))
S_BOT_THIRD_Y=$(( SY + SH - S_THIRD_H ))
S_BRAVE_Y=$(( SY + SH * 30 / 100 ))
S_BRAVE_H=$(( SH * 37 / 100 ))
S_CHAT_W=$(( SW / 3 ))
S_CHAT_H=$(( SH / 4 ))
S_CHAT_X=$(( SX + SW - S_CHAT_W ))
S_CHAT_Y=$(( SY + SH - S_CHAT_H ))
S_HALF_H=$(( SH / 2 ))
S_BOT45_Y=$(( SY + SH * 55 / 100 ))
S_BOT45_H=$(( SH * 45 / 100 ))

# ── Snapshot all windows once ─────────────────────────────────────────────────
ALL_WINDOWS="$(yabai -m query --windows)"

wid_nth() {
  local app="$1" n="$2"
  echo "$ALL_WINDOWS" | jq -r --arg app "$app" --argjson n "$n" '
    map(select(.app == $app)) | sort_by(.id) | .[$n].id // empty'
}

wid_all() {
  local app="$1"
  echo "$ALL_WINDOWS" | jq -r --arg app "$app" '
    map(select(.app == $app)) | sort_by(.id) | .[].id // empty'
}

place() {
  local wid="$1" space="$2" x="$3" y="$4" w="${5:-}" h="${6:-}" sublayer="${7:-}"
  [ -z "$wid" ] && return 0
  yabai -m window "$wid" --space "$space" || true
  if [ -n "$w" ] && [ -n "$h" ]; then
    yabai -m window "$wid" --resize "abs:${w}:${h}" || true
  fi
  yabai -m window "$wid" --move "abs:${x}:${y}" || true
  if [ -n "$sublayer" ]; then
    yabai -m window "$wid" --sub-layer "$sublayer" || true
  fi
}

move_only() {
  local wid="$1" space="$2"
  [ -z "$wid" ] && return 0
  yabai -m window "$wid" --space "$space" || true
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN MONITOR
# ══════════════════════════════════════════════════════════════════════════════

# ── Space 2 (stack): Ghostty, Zed, Vivaldi 1st — fullscreen ──────────────────
while IFS= read -r wid; do
  [ -n "$wid" ] && place "$wid" "$SP_STACK" "$PX" "$PY" "$PW" "$PH"
done < <(wid_all "Ghostty")

wid="$(wid_nth "Zed" 0)"
[ -n "$wid" ] && place "$wid" "$SP_STACK" "$PX" "$PY" "$PW" "$PH"

wid="$(wid_nth "Vivaldi" 0)"
[ -n "$wid" ] && place "$wid" "$SP_STACK" "$PX" "$PY" "$PW" "$PH"

# ── Space 3: Moonlight — move only ───────────────────────────────────────────
wid="$(wid_nth "Moonlight" 0)"
[ -n "$wid" ] && move_only "$wid" "$SP_MOONLIGHT"

# ── Space 4 (remote): League of Legends — fullscreen ─────────────────────────
wid="$(wid_nth "League of Legends" 0)"
[ -n "$wid" ] && place "$wid" "$SP_REMOTE" "$PX" "$PY" "$PW" "$PH"

# ══════════════════════════════════════════════════════════════════════════════
# PORTRAIT MONITOR
# ══════════════════════════════════════════════════════════════════════════════

# ── Space 5 (comms) ──────────────────────────────────────────────────────────
wid="$(wid_nth "Discord" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$SY" "$SW" "$S_THIRD_H"

wid="$(wid_nth "Claude" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_SEVEN15_Y" "$SW" "$S_SEVEN15_H"

wid="$(wid_nth "Vivaldi" 1)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_SEVEN15_Y" "$SW" "$S_SEVEN15_H"

wid="$(wid_nth "Signal" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT_THIRD_Y" "$SW" "$S_THIRD_H"

wid="$(wid_nth "Messages" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT_THIRD_Y" "$SW" "$S_THIRD_H"

wid="$(wid_nth "OBS Studio" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT_THIRD_Y" "$SW" "$S_THIRD_H"

wid="$(wid_nth "Chatterino" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$S_CHAT_X" "$S_CHAT_Y" "$S_CHAT_W" "$S_CHAT_H"

wid="$(wid_nth "Brave Browser" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BRAVE_Y" "$SW" "$S_BRAVE_H" "above"
wid="$(wid_nth "Brave Browser" 1)"
if [ -n "$wid" ]; then
  yabai -m window "$wid" --space "$SP_COMMS" || true
  cur_x="$(yabai -m query --windows --window "$wid" | jq -r '.frame.x | floor')"
  yabai -m window "$wid" --move "abs:${cur_x}:$(( SY + SH * 3 / 100 ))" || true
fi

wid="$(wid_nth "Obsidian" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT45_Y" "$SW" "$S_BOT45_H"

wid="$(wid_nth "ChatGPT" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT45_Y" "$SW" "$S_BOT45_H"

# ── Space 6 (stream) ─────────────────────────────────────────────────────────
wid="$(wid_nth "Stream Deck" 0)"
[ -n "$wid" ] && place "$wid" "$SP_STREAM" "$SX" "$SY" "$SW" "$S_HALF_H"

wid="$(wid_nth "Elgato Wave Link" 0)"
[ -n "$wid" ] && place "$wid" "$SP_STREAM" "$SX" "$(( SY + S_HALF_H ))" "$SW" "$S_HALF_H"

# ══════════════════════════════════════════════════════════════════════════════
# CATCH-ALL: unknown apps → space of first sibling, or space 1 if none
# ══════════════════════════════════════════════════════════════════════════════
echo "$ALL_WINDOWS" | jq -r '
  [.[] | select(
      .app != "Ghostty" and .app != "Zed" and .app != "Vivaldi" and
      .app != "Moonlight" and .app != "League of Legends" and
      .app != "Discord" and .app != "Claude" and .app != "Signal" and
      .app != "Messages" and .app != "OBS Studio" and .app != "Chatterino" and
      .app != "Brave Browser" and .app != "Obsidian" and .app != "ChatGPT" and
      .app != "Stream Deck" and .app != "Elgato Wave Link"
    )]
  | group_by(.app)
  | .[]
  | sort_by(.id)
  | (.[0].space) as $target
  | .[]
  | "\(.id) \($target)"
' | while read -r wid target; do
    [ -n "$wid" ] || continue
    yabai -m window "$wid" --space "$target" || true
  done
