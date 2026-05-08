local config      = require("config")
local spaces      = require("spaces")
local layouts     = require("layouts")
local focus_cycle = require("focus_cycle")
local helpers     = require("helpers")

local M = {}

local AC  = { "cmd", "alt", "ctrl" }
local ACS = { "cmd", "alt", "ctrl", "shift" }

local function bind(mods, key, fn) hs.hotkey.bind(mods, key, fn) end

local function setHorizGrid(cols, col)
  local w = hs.window.focusedWindow()
  if not w then return end
  local f = w:screen():frame()
  w:setFrame(hs.geometry.rect(f.x + col * f.w / cols, f.y, f.w / cols, f.h))
end

local function maximize()
  local w = hs.window.focusedWindow()
  if w then w:setFrame(w:screen():frame()) end
end

local function moveAndFollow(label)
  local w = hs.window.focusedWindow()
  if w then spaces.moveWindowAndFollow(w, label) end
end

local function shiftSpace(_)
  hs.alert.show("move to space unavailable (hs.spaces bug #3698)")
end

local function focusNthSpace(n)
  hs.eventtap.keyStroke({"ctrl"}, tostring(n), 0)
end

function M.setup()
  for key, spec in pairs(config.appHotkeys) do
    bind(AC, key, function()
      if type(spec) == "table" then
        focus_cycle.focusMany(spec)
      else
        focus_cycle.focus(spec)
      end
    end)
  end
  if config.gaming then bind(AC, "g", helpers.focusGaming) end
  bind(AC, "return", helpers.finderHere)

  local labels = {}
  for _, l in ipairs(config.primaryLabels   or {}) do table.insert(labels, l) end
  for _, l in ipairs(config.secondaryLabels or {}) do table.insert(labels, l) end

  for i = 1, 9 do
    local label = labels[i]
    if label then
      bind(AC, tostring(i), function() spaces.focus(label) end)
    else
      bind(AC, tostring(i), function() focusNthSpace(i) end)
    end
  end

  bind(AC, "f",     maximize)
  bind(AC, "left",  function() setHorizGrid(2, 0) end)
  bind(AC, "right", function() setHorizGrid(2, 1) end)
  bind(AC, "z",     function() hs.alert.show("toggle float (n/a)") end)

  bind(ACS, "left",  function() shiftSpace(-1) end)
  bind(ACS, "right", function() shiftSpace(1)  end)
  for i = 1, math.min(9, #labels) do
    local label = labels[i]
    bind(ACS, tostring(i), function() moveAndFollow(label) end)
  end

  bind(ACS, "u", helpers.toggleAbove)
  bind(ACS, "l", layouts.applySecondScreen)
end

return M
