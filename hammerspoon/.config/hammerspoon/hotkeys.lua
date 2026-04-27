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
  for key, app in pairs(config.appHotkeys) do
    bind(AC, key, function() focus_cycle.focus(app) end)
  end
  bind(AC, "g",      helpers.focusGaming)
  bind(AC, "return", helpers.finderHere)

  bind(AC, "1", function() spaces.focus("main")   end)
  bind(AC, "2", function() spaces.focus("stack")  end)
  bind(AC, "3", function() spaces.focus("remote") end)
  bind(AC, "4", function() spaces.focus("comms")  end)
  bind(AC, "5", function() spaces.focus("stream") end)

  for i = 6, 9 do
    bind(AC, tostring(i), function() focusNthSpace(i) end)
  end

  bind(AC, "f",     maximize)
  bind(AC, "left",  function() setHorizGrid(2, 0) end)
  bind(AC, "right", function() setHorizGrid(2, 1) end)
  bind(AC, "z",     function() hs.alert.show("toggle float (n/a)") end)

  bind(ACS, "left",  function() shiftSpace(-1) end)
  bind(ACS, "right", function() shiftSpace(1)  end)
  bind(ACS, "1", function() moveAndFollow("main")   end)
  bind(ACS, "2", function() moveAndFollow("stack")  end)
  bind(ACS, "3", function() moveAndFollow("remote") end)
  bind(ACS, "4", function() moveAndFollow("comms")  end)
  bind(ACS, "5", function() moveAndFollow("stream") end)

  bind(ACS, "u", helpers.toggleAbove)
  bind(ACS, "l", layouts.applySecondScreen)
end

return M
