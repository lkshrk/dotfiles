-- Waking from sleep disconnects every screen; Hyprland parks floating windows on a fallback output and never moves them back.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")
local S = require("hypr.screens.side")

-- On disk because Omarchy reloads the config when a screen wakes without a mode, which resets Lua state.
local function load_saved()
  local frames = {}
  for address, f in pairs(U.load_tsv("wake")) do
    frames[address] = { class = f[1], monitor = f[2], x = tonumber(f[3]), y = tonumber(f[4]), w = tonumber(f[5]), h = tonumber(f[6]) }
  end
  return frames
end

local saved, written = load_saved(), nil

local function save()
  local rows, keys = {}, {}
  for address, f in pairs(saved) do
    rows[address] = { f.class, f.monitor, f.x, f.y, f.w, f.h }
    keys[#keys + 1] = address .. table.concat(rows[address], ",")
  end
  table.sort(keys)
  local key = table.concat(keys, ";")
  if key ~= written then
    U.save_tsv("wake", rows)
    written = key
  end
end

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

-- Screens can shove windows again long after the wake settles, so every snapshot also repairs strays.
local function remember()
  if not all_screens() then return end
  local frames, stray = {}, false
  for _, w in ipairs(hl.get_windows()) do
    if placeable(w) then
      local x, y = U.xy(w.at)
      local width, height = U.xy(w.size)
      local b = U.bounds(w.monitor)
      if fits(x, y, width, height, b) then
        frames[w.address] = { class = w.class, monitor = w.monitor.name, x = x - b.x, y = y - b.y, w = width, h = height }
      else
        local f = saved[w.address]
        frames[w.address] = f
        if slotted(w) or (f and f.class == w.class and f.monitor == w.monitor.name) then stray = true end
      end
    end
  end
  saved = frames
  save()
  if stray then restore() end
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
