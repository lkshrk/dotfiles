local spaces = require("spaces")
local state  = require("state")
local M = {}

local function isPrimary(win)
  local primary = hs.screen.primaryScreen()
  return win:screen() and win:screen():id() == primary:id()
end

local function firstSpaceID(win)
  local sps = hs.spaces.windowSpaces(win) or {}
  return sps[1]
end

function M.focus(appName)
  local app = hs.application.find(appName)
  if not app then
    hs.application.launchOrFocus(appName)
    return
  end

  local valid = {}
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then table.insert(valid, w) end
  end
  if #valid == 0 then
    hs.application.launchOrFocus(appName)
    return
  end

  local stackID = spaces.id("stack")

  table.sort(valid, function(a, b)
    local ta, tb = state.lastFocused(a:id()), state.lastFocused(b:id())
    if ta ~= tb then return ta > tb end

    local pa, pb = isPrimary(a), isPrimary(b)
    if pa ~= pb then return pa end

    local sa, sb = firstSpaceID(a), firstSpaceID(b)
    if (sa == stackID) ~= (sb == stackID) then return sa == stackID end
    if sa ~= sb then return (sa or 0) < (sb or 0) end
    return a:id() < b:id()
  end)

  local current = hs.window.focusedWindow()
  local currentID = current and current:id()
  local nextWin = valid[1]
  for i, w in ipairs(valid) do
    if w:id() == currentID then
      nextWin = valid[(i % #valid) + 1]
      break
    end
  end

  if nextWin then nextWin:focus() end
end

function M.focusMany(apps)
  if #apps == 0 then return end
  if #apps == 1 then return M.focus(apps[1]) end

  local current = hs.application.frontmostApplication()
  local currentName = current and current:name() or ""

  local startIdx = 1
  for i, name in ipairs(apps) do
    if name == currentName then
      startIdx = (i % #apps) + 1
      break
    end
  end

  for offset = 0, #apps - 1 do
    local idx = ((startIdx - 1 + offset) % #apps) + 1
    local name = apps[idx]
    if hs.application.find(name) then
      M.focus(name)
      return
    end
  end

  hs.application.launchOrFocus(apps[1])
end

return M
