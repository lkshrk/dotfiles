-- Waking from sleep disconnects every screen; Hyprland parks floating windows on a fallback output and never moves them back.
local U = require("hypr.screens.util")

local saved = {}

-- A window spilling off its screen was shoved there, so its last good frame is kept instead.
local function fits(x, y, width, height, b)
  return x >= b.x and y >= b.y and x + width <= b.x + b.w and y + height <= b.y + b.h
end

local function remember()
  local frames = {}
  for _, w in ipairs(hl.get_windows()) do
    local m = w.mapped and w.floating and (w.fullscreen or 0) == 0 and w.monitor
    if m then
      local x, y = U.xy(w.at)
      local width, height = U.xy(w.size)
      local b = U.bounds(m)
      if fits(x, y, width, height, b) then
        frames[w.address] = { class = w.class, monitor = m.name, x = x - b.x, y = y - b.y, w = width, h = height }
      else
        frames[w.address] = saved[w.address]
      end
    end
  end
  saved = frames
end

local function restore()
  U.state.placing = true
  for _, w in ipairs(hl.get_windows()) do
    local f = saved[w.address]
    if f and f.class == w.class and w.mapped and w.floating and w.monitor and w.monitor.name == f.monitor then
      local b = U.bounds(w.monitor)
      hl.dispatch(hl.dsp.window.resize({ x = f.w, y = f.h, window = w }))
      hl.dispatch(hl.dsp.window.move({ x = b.x + f.x, y = b.y + f.y, window = w }))
    end
  end
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
