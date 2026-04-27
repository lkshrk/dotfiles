local config = require("config")
local M = { labels = {} }

local readyQueue = {}

local function userSpacesFor(screen)
  local ids = hs.spaces.spacesForScreen(screen) or {}
  local user = {}
  for _, id in ipairs(ids) do
    if hs.spaces.spaceType(id) == "user" then
      table.insert(user, id)
    end
  end
  return user
end

function M.secondaryScreen()
  local primary = hs.screen.primaryScreen()
  for _, scr in ipairs(hs.screen.allScreens()) do
    if scr:id() ~= primary:id() then return scr end
  end
end

function M.refreshLabels()
  M.labels = {}

  local primarySpaces = userSpacesFor(hs.screen.primaryScreen())
  for i, label in ipairs(config.primaryLabels) do
    if primarySpaces[i] then M.labels[label] = primarySpaces[i] end
  end

  local secondary = M.secondaryScreen()
  if secondary then
    local secondarySpaces = userSpacesFor(secondary)
    for i, label in ipairs(config.secondaryLabels) do
      if secondarySpaces[i] then M.labels[label] = secondarySpaces[i] end
    end
  end
end

function M.id(label)
  return M.labels[label]
end

function M.ordinal(label)
  for i, l in ipairs(config.primaryLabels) do
    if l == label then return i end
  end
  for i, l in ipairs(config.secondaryLabels) do
    if l == label then return #config.primaryLabels + i end
  end
end

-- Switch to a labeled space using macOS's native "Switch to Desktop N"
-- shortcut. Requires the user to have enabled those shortcuts in
-- System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
function M.focus(label)
  local n = M.ordinal(label)
  if not n then return end
  hs.eventtap.keyStroke({"ctrl"}, tostring(n), 0)
end

-- Moving a window between spaces is currently unsupported: hs.spaces.moveWindowToSpace
-- is broken on macOS Sequoia (returns true but does nothing). See
-- https://github.com/Hammerspoon/hammerspoon/issues/3698. The only known
-- working alternatives are yabai's scripting addition (requires SIP off) or
-- Drag.spoon's Mission-Control UI automation (visible MC flash).
function M.moveWindowAndFollow(_, _)
  hs.alert.show("move to space unavailable (hs.spaces bug #3698)")
end

function M.deficit()
  local secondary = M.secondaryScreen()
  local primaryHave   = #userSpacesFor(hs.screen.primaryScreen())
  local secondaryHave = secondary and #userSpacesFor(secondary) or 0

  return {
    primary      = math.max(0, #config.primaryLabels   - primaryHave),
    secondary    = math.max(0, (secondary and #config.secondaryLabels or 0) - secondaryHave),
    hasSecondary = secondary ~= nil,
  }
end

function M.isReady()
  local d = M.deficit()
  return d.primary == 0 and d.secondary == 0
end

function M.onReady(fn)
  if M.isReady() then fn(); return end
  table.insert(readyQueue, fn)
end

local function flushIfReady()
  if not M.isReady() then return end
  local q = readyQueue
  readyQueue = {}
  for _, fn in ipairs(q) do
    local ok, err = pcall(fn)
    if not ok then print("spaces.onReady callback error: " .. tostring(err)) end
  end
end

local function warnIfMissing()
  local d = M.deficit()
  if d.primary == 0 and d.secondary == 0 then return end

  local lines = {}
  if d.primary > 0 then
    table.insert(lines, string.format("Create %d more space%s on the primary display",
      d.primary, d.primary == 1 and "" or "s"))
  end
  if d.secondary > 0 and d.hasSecondary then
    table.insert(lines, string.format("Create %d more space%s on the secondary display",
      d.secondary, d.secondary == 1 and "" or "s"))
  end

  local msg = table.concat(lines, "\n")
  hs.notify.new({
    title = "Set up Mission Control spaces",
    informativeText = msg,
    withdrawAfter = 0,
  }):send()
  hs.alert.show(msg, 6)
end

function M.start()
  M.refreshLabels()
  warnIfMissing()
  M.screenWatcher = hs.screen.watcher.new(function()
    M.refreshLabels()
    warnIfMissing()
  end):start()
  M.spaceWatcher = hs.spaces.watcher.new(function()
    M.refreshLabels()
    warnIfMissing()
    flushIfReady()
  end):start()
end

return M
