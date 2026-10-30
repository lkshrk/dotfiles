-- Portrait screen: app slots, halves and thirds.
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

return S
