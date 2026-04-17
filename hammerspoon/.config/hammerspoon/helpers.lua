local spaces = require("spaces")
local M = {}

-- Always-on-top for foreign windows is not achievable on macOS without either
-- SIP disabled (yabai scripting addition) or paid tooling. Left as an alert so
-- the keybind still surfaces the intent.
function M.toggleAbove()
  hs.alert.show("always-on-top unavailable without SIP off")
end

function M.finderHere()
  local activeID = hs.spaces.focusedSpace()
  local finder = hs.application.find("Finder")
  if finder then
    for _, w in ipairs(finder:allWindows()) do
      for _, s in ipairs(hs.spaces.windowSpaces(w) or {}) do
        if s == activeID then w:focus(); return end
      end
    end
  end

  hs.osascript.applescript([[
    tell application "Finder"
      activate
      make new Finder window
    end tell
  ]])

  hs.timer.doAfter(0.25, function()
    local f = hs.application.find("Finder")
    if not f then return end
    local newest
    for _, w in ipairs(f:allWindows()) do
      if (not newest) or w:id() > newest:id() then newest = w end
    end
    if newest then
      hs.spaces.moveWindowToSpace(newest, activeID)
      newest:focus()
    end
  end)
end

function M.focusGaming()
  local config = require("config")
  local g = config.gaming
  if not g then return end

  local targets = {}
  for _, name in ipairs(g.apps or {}) do targets[name:lower()] = true end

  for _, w in ipairs(hs.window.allWindows()) do
    local title = (w:title() or ""):lower()
    local app   = (w:application() and w:application():name() or ""):lower()
    if targets[title] or targets[app] then
      w:focus()
      if g.warpMouse then
        hs.timer.doAfter(0.1, function()
          local f = w:frame()
          local pt = { x = f.x + f.w / 2, y = f.y + f.h / 2 }
          hs.mouse.absolutePosition(pt)
          hs.eventtap.leftClick(pt)
        end)
      end
      return
    end
  end

  if g.label then spaces.focus(g.label) end
end

return M
