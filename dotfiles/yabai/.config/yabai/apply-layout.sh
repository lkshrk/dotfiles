#!/usr/bin/env bash
set -euo pipefail
TARGET_WINDOW_ID="${1:-}"

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
# Labels maintained by relabel-spaces.sh; numeric indices drift when extra
# spaces exist, labels don't. Moonlight and League share the remote space.
SP_STACK=stack
SP_MOONLIGHT=remote
SP_REMOTE=remote
SP_COMMS=comms
SP_STREAM=stream

# ── Portrait dimensions ──────────────────────────────────────────────────────
S_THIRD_H=$(( SH / 3 ))
S_SEVEN15_H=$(( SH * 7 / 15 ))
S_SEVEN15_Y=$(( SY + SH - S_SEVEN15_H ))
S_BOT_THIRD_Y=$(( SY + SH - S_THIRD_H ))
S_BRAVE_Y=$(( SY + SH * 30 / 100 ))
S_BRAVE_H=1050
S_CHAT_W=$(( SW / 3 ))
S_CHAT_H=$(( SH / 4 ))
S_CHAT_X=$(( SX + SW - S_CHAT_W - 1 ))
S_CHAT_Y=$(( SY + SH - S_CHAT_H - 43 ))
S_HALF_H=$(( SH / 2 ))
S_BOT45_Y=$(( SY + SH * 55 / 100 ))
S_BOT45_H=$(( SH * 45 / 100 ))

# ── Snapshot all windows once ─────────────────────────────────────────────────
ALL_WINDOWS="$(yabai -m query --windows)"
if [ -n "$TARGET_WINDOW_ID" ]; then
  ALL_WINDOWS="$(echo "$ALL_WINDOWS" | jq --argjson wid "$TARGET_WINDOW_ID" 'map(select(.id == $wid))')"
fi

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

wid_at_frame() {
  local app="$1" x="$2" y="$3" w="$4" h="$5"
  echo "$ALL_WINDOWS" | jq -r \
    --arg app "$app" \
    --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" '
      map(select(
        .app == $app and
        (.frame.x | floor) == $x and (.frame.y | floor) == $y and
        (.frame.w | floor) == $w and (.frame.h | floor) == $h
      ))
      | first.id // empty
    '
}

HELIUM_PRIMARY_WID=""
if [ -n "$(wid_nth "Helium" 0)" ]; then
  HELIUM_PRIMARY_FRAME="$(
    osascript -l JavaScript -e '
      const windows = Application("Helium").windows();
      const primary = windows.find(window => {
        const tabs = window.tabs();
        return tabs.length && String(tabs[0].url()).startsWith("https://mail.google.com/");
      });
      if (primary) {
        const bounds = primary.bounds();
        [bounds.x, bounds.y, bounds.width, bounds.height].join(" ");
      }
    ' 2>/dev/null || true
  )"
  if [ -n "$HELIUM_PRIMARY_FRAME" ]; then
    read -r hx hy hw hh <<< "$HELIUM_PRIMARY_FRAME"
    HELIUM_PRIMARY_WID="$(wid_at_frame "Helium" "$hx" "$hy" "$hw" "$hh")"
  fi
fi
HELIUM_PRIMARY_WID="${HELIUM_PRIMARY_WID:-$(wid_nth "Helium" 0)}"
HELIUM_SECONDARY_WID="$(
  echo "$ALL_WINDOWS" | jq -r --argjson primary "${HELIUM_PRIMARY_WID:-0}" '
    map(select(.app == "Helium" and .id != $primary))
    | sort_by(.id)
    | first.id // empty
  '
)"

place() {
  local wid="$1" space="$2" x="$3" y="$4" w="${5:-}" h="${6:-}" sublayer="${7:-}"
  [ -z "$wid" ] && return 0
  yabai -m window "$wid" --space "$space" || true
  yabai -m window "$wid" --move "abs:${x}:${y}" || true
  if [ -n "$w" ] && [ -n "$h" ]; then
    yabai -m window "$wid" --resize "abs:${w}:${h}" || true
  fi
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

# ── Space 2 (stack): Ghostty, Zed, primary Helium — fullscreen ────────────────
while IFS= read -r wid; do
  [ -n "$wid" ] && place "$wid" "$SP_STACK" "$PX" "$PY" "$PW" "$PH"
done < <(wid_all "Ghostty")

wid="$(wid_nth "Zed" 0)"
[ -n "$wid" ] && place "$wid" "$SP_STACK" "$PX" "$PY" "$PW" "$PH"

wid="$HELIUM_PRIMARY_WID"
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

wid="$HELIUM_SECONDARY_WID"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_SEVEN15_Y" "$SW" "$S_SEVEN15_H"

for app in Signal Messages Telegram; do
  wid="$(wid_nth "$app" 0)"
  [ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT_THIRD_Y" "$SW" "$S_THIRD_H"
done

wid="$(wid_nth "OBS Studio" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT_THIRD_Y" "$SW" "$S_THIRD_H"

wid="$(wid_nth "Chatterino" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$S_CHAT_X" "$S_CHAT_Y" "$S_CHAT_W" "$S_CHAT_H"

wid="$(
  echo "$ALL_WINDOWS" | jq -r '
    map(select(.app == "Brave Browser" and .title != "Picture in Picture"))
    | sort_by(.id)
    | first.id // empty
  '
)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BRAVE_Y" "$SW" "$S_BRAVE_H" "auto"

wid="$(
  echo "$ALL_WINDOWS" | jq -r '
    map(select(.app == "Brave Browser" and .title == "Picture in Picture"))
    | first.id // empty
  '
)"
[ -n "$wid" ] && "$(dirname "$0")/place-pip.sh" "$wid"

wid="$(wid_nth "Obsidian" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT45_Y" "$SW" "$S_BOT45_H"

wid="$(wid_nth "ChatGPT Classic" 0)"
[ -n "$wid" ] && place "$wid" "$SP_COMMS" "$SX" "$S_BOT45_Y" "$SW" "$S_BOT45_H"

# ── Space 6 (stream) ─────────────────────────────────────────────────────────
wid="$(wid_nth "Stream Deck" 0)"
[ -n "$wid" ] && place "$wid" "$SP_STREAM" "$SX" "$SY" "$SW" "$S_HALF_H"

wid="$(wid_nth "Elgato Wave Link" 0)"
[ -n "$wid" ] && place "$wid" "$SP_STREAM" "$SX" "$(( SY + S_HALF_H ))" "$SW" "$S_HALF_H"

# ══════════════════════════════════════════════════════════════════════════════
# CATCH-ALL: unknown apps → stack, preserving size
# ══════════════════════════════════════════════════════════════════════════════
echo "$ALL_WINDOWS" | jq -r '
  [.[] | select(
      .app != "Ghostty" and .app != "Zed" and .app != "Helium" and
      .app != "Moonlight" and .app != "League of Legends" and
      .app != "Discord" and .app != "Claude" and .app != "Signal" and
      .app != "Messages" and .app != "Telegram" and
      .app != "OBS Studio" and .app != "Chatterino" and
      .app != "Brave Browser" and .app != "Obsidian" and .app != "ChatGPT Classic" and
      .app != "Stream Deck" and .app != "Elgato Wave Link"
    )]
  | .[]
  | "\(.id) stack"
' | while read -r wid target; do
    [ -n "$wid" ] || continue
    yabai -m window "$wid" --space "$target" || true
  done
