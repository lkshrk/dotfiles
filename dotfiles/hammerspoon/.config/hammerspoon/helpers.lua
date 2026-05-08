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

  local all = hs.window.allWindows()

  -- Towerr: title match
  local towerrWins = {}
  for _, w in ipairs(all) do
    if w:isStandard() and (w:title() or ""):lower() == "towerr" then
      table.insert(towerrWins, w)
    end
  end

  -- Moonlight: app match (only if towerr absent)
  local moonlightWins = {}
  if #towerrWins == 0 then
    for _, w in ipairs(all) do
      local app = (w:application() and w:application():name() or ""):lower()
      if w:isStandard() and app == "moonlight" then
        table.insert(moonlightWins, w)
      end
    end
  end

  local streamWins = #towerrWins > 0 and towerrWins or moonlightWins

  -- League: prefer game window (empty title) over client
  local leagueGameWins, leagueAllWins = {}, {}
  for _, w in ipairs(all) do
    local app = (w:application() and w:application():name() or ""):lower()
    if w:isStandard() and app == "league of legends" then
      table.insert(leagueAllWins, w)
      if (w:title() or "") == "" then
        table.insert(leagueGameWins, w)
      end
    end
  end
  local leagueWins = #leagueGameWins > 0 and leagueGameWins or leagueAllWins

  -- Pool: stream pick + league pick
  local pool = {}
  for _, w in ipairs(streamWins) do table.insert(pool, w) end
  for _, w in ipairs(leagueWins)  do table.insert(pool, w) end

  if #pool == 0 then
    if g.label then spaces.focus(g.label) end
    return
  end

  -- Cycle: find current window in pool, advance to next
  local current   = hs.window.focusedWindow()
  local currentID = current and current:id()
  local nextWin   = pool[1]
  for i, w in ipairs(pool) do
    if w:id() == currentID then
      nextWin = pool[(i % #pool) + 1]
      break
    end
  end

  if nextWin then
    nextWin:focus()
    if g.warpMouse then
      hs.timer.doAfter(0.1, function()
        local f  = nextWin:frame()
        local pt = { x = f.x + f.w / 2, y = f.y + f.h / 2 }
        hs.mouse.absolutePosition(pt)
        hs.eventtap.leftClick(pt)
      end)
    end
  end
end

return M
