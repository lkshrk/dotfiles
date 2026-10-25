-- Portrait screen: app slots, halves and thirds, and restoring frames after the monitors wake.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")

local S = {}

function S.place(w)
  local slot = C.slots[U.app(w)] or { row = C.MID }
  U.frame(w, U.cell(U.area(hl.get_monitor(C.side)), slot.row, slot.rows or 1, slot.col or 0, slot.cols or 3))
  if slot.above then hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w })) end
end

local function snap(value, unit, max)
  return math.max(0, math.min(max, math.floor(value / unit + 0.5)))
end

-- Vertical stops as { first third, thirds tall }; up/down walk them, and pushing past either end fills the height.
local stops = { { 0, 1 }, { 0, 2 }, { 1, 1 }, { 1, 2 }, { 2, 1 } }

local function stop_index(row, rows)
  for i, s in ipairs(stops) do
    if s[1] == row and s[2] == rows then return i end
  end
end

-- Left/right takes that half; pressing toward the half the window already sits on fills the width again.
function S.step(w, dir)
  local a = U.area(hl.get_monitor(C.side))
  local x, y = U.xy(w.at)
  local width, height = U.xy(w.size)
  local row, rows = snap(y - a.y, a.h / 3, 2), math.max(1, snap(height, a.h / 3, 3))
  local half = width < a.w * 0.75 and (x - a.x < a.w / 4 and "left" or "right") or nil
  if dir == "up" or dir == "down" then
    local i = stop_index(row, rows)
    local at_end = i and ((dir == "up" and i == 1) or (dir == "down" and i == #stops))
    if half and at_end then
      -- A half-width window pushed against the top or bottom widens first, keeping its height.
      half = nil
    else
      local next_stop
      if rows == 3 then
        next_stop = stops[dir == "up" and 1 or #stops]
      elseif i and not at_end then
        next_stop = stops[i + (dir == "up" and -1 or 1)]
      end
      row, rows = next_stop and next_stop[1] or 0, next_stop and next_stop[2] or 3
    end
  else
    half = half ~= dir and dir or nil
  end
  local box = U.cell(a, row, rows, 0, 3)
  if half then
    box.w = math.floor(a.w / 2)
    box.x = math.floor(a.x) + (half == "right" and box.w or 0)
  end
  U.frame(w, box)
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
end

-- Waking from DPMS re-adds the portrait screen unrotated for a moment, which shoves its floating windows around.
local side_frames = {}

local function remember()
  local side = hl.get_monitor(C.side)
  if not side or side.transform % 2 == 0 then return end
  local frames = {}
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped and w.floating and w.monitor == side then
      local x, y = U.xy(w.at)
      local width, height = U.xy(w.size)
      frames[w.address] = { x = x, y = y, w = width, h = height }
    end
  end
  side_frames = frames
end

local function restore()
  local side = hl.get_monitor(C.side)
  if not side or side.transform % 2 == 0 then return end
  U.state.placing = true
  for _, w in ipairs(hl.get_windows()) do
    local f = side_frames[w.address]
    if f and w.mapped and w.floating then
      hl.dispatch(hl.dsp.window.resize({ x = f.w, y = f.h, window = w }))
      hl.dispatch(hl.dsp.window.move({ x = f.x, y = f.y, window = w }))
    end
  end
  U.state.placing = false
end

local settle = hl.timer(restore, { timeout = 1500, type = "oneshot" })
settle:set_enabled(false)
local snapshot = hl.timer(remember, { timeout = 5000, type = "repeat" })

-- Re-armed on every event, so a long burst keeps snapshots off until it has been quiet for 4 s.
local resume = hl.timer(function() snapshot:set_enabled(true) end, { timeout = 4000, type = "oneshot" })
resume:set_enabled(false)

for _, event in ipairs({ "monitor.added", "monitor.removed", "monitor.layout_changed" }) do
  hl.on(event, function()
    snapshot:set_enabled(false)
    settle:set_timeout(1500)
    settle:set_enabled(true)
    resume:set_timeout(4000)
    resume:set_enabled(true)
  end)
end

return S
