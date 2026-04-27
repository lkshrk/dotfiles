local config = require("config")
local spaces = require("spaces")
local M = {}

local function findWindow(appName, spaceID)
  local app = hs.application.find(appName)
  if not app then return nil end
  local matches = {}
  for _, w in ipairs(app:allWindows()) do
    if not spaceID then
      table.insert(matches, w)
    else
      for _, s in ipairs(hs.spaces.windowSpaces(w) or {}) do
        if s == spaceID then table.insert(matches, w); break end
      end
    end
  end
  table.sort(matches, function(a, b) return a:id() < b:id() end)
  return matches[#matches]
end

local function place(appName, spaceID, frame)
  local w = findWindow(appName, spaceID)
  if not w then return end
  w:setFrame(hs.geometry.rect(frame.x, frame.y, frame.w, frame.h))
end

local function placeCenteredScaled(appName, spaceID, scale, screenFrame)
  local app = hs.application.find(appName)
  if not app then return end
  local w = app:allWindows()[1]
  if not w then return end
  hs.spaces.moveWindowToSpace(w, spaceID)
  local sw, sh = screenFrame.w * scale, screenFrame.h * scale
  w:setFrame(hs.geometry.rect(
    screenFrame.x + (screenFrame.w - sw) / 2,
    screenFrame.y + (screenFrame.h - sh) / 2,
    sw, sh
  ))
end

local function placeCenteredBottomInRegion(appName, spaceID, region)
  local w = findWindow(appName, spaceID)
  if not w then return end
  local cf = w:frame()
  w:setTopLeft({
    x = region.x + (region.w - cf.w) / 2,
    y = region.y + region.h - cf.h,
  })
end

function M.applyMainScreen()
  local f = hs.screen.primaryScreen():frame()
  local stackID  = spaces.id("stack")
  local remoteID = spaces.id("remote")
  local full = { x = f.x, y = f.y, w = f.w, h = f.h }

  if stackID then
    place("Ghostty", stackID, full)
    place("Zed",     stackID, full)
    place("Vivaldi", stackID, full)
  end
  if remoteID then
    place("Moonlight",         remoteID, full)
    place("League of Legends", remoteID, full)
  end
end

function M.applySecondScreen()
  local secondary = spaces.secondaryScreen()
  if not secondary then return end

  local f = secondary:frame()
  local commsID  = spaces.id("comms")
  local streamID = spaces.id("stream")

  local halfW          = f.w / 2
  local halfH          = f.h / 2
  local quarterH       = f.h / 4
  local rightX         = f.x + halfW
  local bottomHalfY    = f.y + halfH
  local bottomQuarterY = f.y + f.h - quarterH
  local leftInset      = 50

  if commsID then
    place("Discord",  commsID, { x=f.x,           y=f.y,         w=halfW,           h=f.h  })
    place("ChatGPT",  commsID, { x=f.x+leftInset, y=f.y,         w=halfW-leftInset, h=f.h  })
    place("Vivaldi",  commsID, { x=f.x+leftInset, y=f.y,         w=halfW-leftInset, h=f.h  })
    place("Signal",   commsID, { x=f.x,           y=bottomHalfY, w=halfW,           h=halfH })
    place("Messages", commsID, { x=f.x,           y=bottomHalfY, w=halfW,           h=halfH })
    placeCenteredBottomInRegion("Chatterino", commsID,
      { x=rightX, y=bottomHalfY, w=halfW, h=halfH })
    place("OBS",           commsID, { x=rightX, y=bottomQuarterY, w=halfW, h=f.h * 3/4 })
    place("Brave Browser", commsID, { x=rightX, y=f.y,            w=halfW, h=f.h * 3/4 })
  end

  if streamID then
    placeCenteredScaled("Obsidian", streamID, 0.75, f)
    place("Stream Deck",      streamID, { x=f.x,    y=f.y, w=halfW, h=f.h })
    place("Elgato Wave Link", streamID, { x=rightX, y=f.y, w=halfW, h=f.h })
  end
end

function M.applyCatchAll()
  local mainID = spaces.id("main")
  if not mainID then return end
  for _, w in ipairs(hs.window.allWindows()) do
    local app = w:application() and w:application():name() or ""
    if not config.managedApps[app] then
      hs.spaces.moveWindowToSpace(w, mainID)
    end
  end
end

function M.applyAll()
  M.applyMainScreen()
  M.applySecondScreen()
  M.applyCatchAll()
end

return M
