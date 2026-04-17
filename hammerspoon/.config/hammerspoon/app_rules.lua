local config = require("config")
local spaces = require("spaces")
local M = {}

-- Per-app spawn counter. Only used when a rule is a list (Nth window → Nth
-- label). List-form rules are currently a Topaz-only concern (Vivaldi).
local counters = {}

local function resolveLabel(appName)
  local rule = config.appRules[appName]
  if type(rule) == "string" then
    return rule
  end
  if type(rule) == "table" then
    counters[appName] = (counters[appName] or 0) + 1
    local idx = counters[appName]
    return rule[idx] or rule[#rule]
  end
  return nil
end

local function placeWindow(win, appName)
  local label = resolveLabel(appName)
  if not label then return end
  local id = spaces.id(label)
  if id then hs.spaces.moveWindowToSpace(win, id) end
end

function M.applyToExisting()
  counters = {}
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
