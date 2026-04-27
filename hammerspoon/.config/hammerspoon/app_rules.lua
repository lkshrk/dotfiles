local config = require("config")
local spaces = require("spaces")
local M = {}

local vivaldiCount = 0

local function placeWindow(win, appName)
  local label = config.appRules[appName]

  -- Vivaldi launches two windows; first goes to comms, second to stack.
  if appName == "Vivaldi" then
    vivaldiCount = vivaldiCount + 1
    label = (vivaldiCount == 1) and "comms" or "stack"
  end

  if not label then return end
  local id = spaces.id(label)
  if id then hs.spaces.moveWindowToSpace(win, id) end
end

function M.applyToExisting()
  vivaldiCount = 0
  for _, w in ipairs(hs.window.allWindows()) do
    local app = w:application() and w:application():name() or ""
    placeWindow(w, app)
  end
end

function M.start()
  M.filter = hs.window.filter.new(true)
  M.filter:subscribe(hs.window.filter.windowCreated, function(win, appName)
    placeWindow(win, appName)
  end)
end

return M
