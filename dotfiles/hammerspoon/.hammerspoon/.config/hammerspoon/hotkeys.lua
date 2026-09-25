local M = {}

local HYPER = { "cmd", "alt", "ctrl" }

local function bind(mods, key, fn)
  hs.hotkey.bind(mods, key, fn)
end

local function focusedWindow()
  return hs.window.focusedWindow()
end

local function maximize()
  local w = focusedWindow()
  if w then w:setFrame(w:screen():frame()) end
end

local function tileHalf(side)
  local w = focusedWindow()
  if not w then return end

  local f = w:screen():frame()
  local halfW = f.w / 2
  local x = f.x
  if side == "right" then
    x = f.x + halfW
  end
  w:setFrame(hs.geometry.rect(x, f.y, halfW, f.h))
end

local function focusDesktop(n)
  hs.eventtap.keyStroke({ "ctrl" }, tostring(n), 0)
end

local function focusApp(name)
  local app = hs.application.find(name)
  if app then
    app:activate(true)
    return
  end
  hs.application.launchOrFocus(name)
end

function M.setup()
  local config = require("config")

  for key, app in pairs(config.appHotkeys or {}) do
    bind(HYPER, key, function()
      focusApp(app)
    end)
  end

  bind(HYPER, "f", maximize)
  bind(HYPER, "left", function() tileHalf("left") end)
  bind(HYPER, "right", function() tileHalf("right") end)

  for i = 1, 9 do
    bind(HYPER, tostring(i), function()
      focusDesktop(i)
    end)
  end
end

return M
