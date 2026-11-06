-- Waking from sleep disconnects every screen; Hyprland parks floating windows on a fallback output and never moves them back.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")
local S = require("hypr.screens.side")

local saved = {}

-- A window spilling off its screen was shoved there, so its last good frame is kept instead.
local function fits(x, y, width, height, b)
  return x >= b.x and y >= b.y and x + width <= b.x + b.w and y + height <= b.y + b.h
end

-- While a screen sleeps its windows sit elsewhere, and a snapshot then would overwrite their frames for good.
local function all_screens()
  return hl.get_monitor(C.main) ~= nil and hl.get_monitor(C.top) ~= nil and hl.get_monitor(C.side) ~= nil
end

local function placeable(w)
  return w.mapped and w.floating and (w.fullscreen or 0) == 0 and w.monitor
end

local function slotted(w)
  return w.workspace and C.side_workspaces[w.workspace.name] and not U.transient(w)
end

local function remember()
  if not all_screens() then return end
  local frames = {}
  for _, w in ipairs(hl.get_windows()) do
    if placeable(w) then
      local x, y = U.xy(w.at)
      local width, height = U.xy(w.size)
      local b = U.bounds(w.monitor)
      if fits(x, y, width, height, b) then
        frames[w.address] = { class = w.class, monitor = w.monitor.name, x = x - b.x, y = y - b.y, w = width, h = height }
      else
        frames[w.address] = saved[w.address]
      end
    end
  end
  saved = frames
end

-- Side-screen windows go back to their slots, since a shifted frame there can still lie fully on screen.
local function restore()
  if not all_screens() then return end
  U.state.placing = true
  local above = {}
  for _, w in ipairs(hl.get_windows()) do
    local f = saved[w.address]
    if placeable(w) and slotted(w) then
      if (C.slots[U.app(w)] or {}).above then above[#above + 1] = w else S.place(w) end
    elseif f and f.class == w.class and placeable(w) and w.monitor.name == f.monitor then
      local b = U.bounds(w.monitor)
      hl.dispatch(hl.dsp.window.resize({ x = f.w, y = f.h, window = w }))
      hl.dispatch(hl.dsp.window.move({ x = b.x + f.x, y = b.y + f.y, window = w }))
    end
  end
  for _, w in ipairs(above) do S.place(w) end
  U.state.placing = false
end

local settle = hl.timer(restore, { timeout = 1500, type = "oneshot" })
settle:set_enabled(false)
local snapshot = hl.timer(remember, { timeout = 5000, type = "repeat" })

-- Restores once more before snapshots resume, in case the screens shuffled windows again after the first pass.
local resume = hl.timer(function()
  restore()
  snapshot:set_enabled(true)
end, { timeout = 5000, type = "oneshot" })
resume:set_enabled(false)

for _, event in ipairs({ "monitor.added", "monitor.removed", "monitor.layout_changed" }) do
  hl.on(event, function()
    snapshot:set_enabled(false)
    settle:set_timeout(1500)
    settle:set_enabled(true)
    resume:set_timeout(5000)
    resume:set_enabled(true)
  end)
end

remember()
