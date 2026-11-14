local config = require("config")
local spaces = require("spaces")
local M = {}

local function placeWindow(win, appName)
  local label = config.appRules[appName]

  if not label then return end
  local id = spaces.id(label)
  if id then hs.spaces.moveWindowToSpace(win, id) end
end

function M.applyToExisting()
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
