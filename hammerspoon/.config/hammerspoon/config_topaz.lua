local M = {
  primaryLabels   = { "main", "stack", "remote" },
  secondaryLabels = { "comms", "stream" },

  appRules = {
    ["Ghostty"]           = "stack",
    ["Zed"]               = "stack",
    ["Moonlight"]         = "remote",
    ["League of Legends"] = "remote",
    ["Discord"]           = "comms",
    ["ChatGPT"]           = "comms",
    ["Signal"]            = "comms",
    ["Messages"]          = "comms",
    ["Chatterino"]        = "comms",
    ["OBS"]               = "comms",
    ["Brave Browser"]     = "comms",
    ["Obsidian"]          = "comms",
    ["Stream Deck"]       = "stream",
    ["Elgato Wave Link"]  = "stream",
    ["Vivaldi"]           = { "comms", "stack" },
  },

  appHotkeys = {
    a = "ChatGPT",
    b = "Vivaldi",
    c = "Chatterino",
    d = "Discord",
    o = "OBS",
    v = "Brave Browser",
  },

  gaming = {
    apps      = { "Towerr", "Moonlight" },
    label     = "remote",
    warpMouse = true,
  },
}

function M.applyMainScreen(layouts, spaces)
  local f = hs.screen.primaryScreen():frame()
  local stackID  = spaces.id("stack")
  local remoteID = spaces.id("remote")
  local full = { x = f.x, y = f.y, w = f.w, h = f.h }

  if stackID then
    layouts.place("Ghostty", stackID, full)
    layouts.place("Zed",     stackID, full)
    layouts.place("Vivaldi", stackID, full)
  end
  if remoteID then
    layouts.place("Moonlight",         remoteID, full)
    layouts.place("League of Legends", remoteID, full)
  end
end

function M.applySecondScreen(layouts, spaces)
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
    layouts.place("Discord",  commsID, { x=f.x,           y=f.y,         w=halfW,           h=f.h  })
    layouts.place("ChatGPT",  commsID, { x=f.x+leftInset, y=f.y,         w=halfW-leftInset, h=f.h  })
    layouts.place("Vivaldi",  commsID, { x=f.x+leftInset, y=f.y,         w=halfW-leftInset, h=f.h  })
    layouts.place("Signal",   commsID, { x=f.x,           y=bottomHalfY, w=halfW,           h=halfH })
    layouts.place("Messages", commsID, { x=f.x,           y=bottomHalfY, w=halfW,           h=halfH })
    layouts.placeCenteredBottomInRegion("Chatterino", commsID,
      { x=rightX, y=bottomHalfY, w=halfW, h=halfH })
    layouts.place("OBS",           commsID, { x=rightX, y=bottomQuarterY, w=halfW, h=f.h * 3/4 })
    layouts.place("Brave Browser", commsID, { x=rightX, y=f.y,            w=halfW, h=f.h * 3/4 })
  end

  if streamID then
    layouts.placeCenteredScaled("Obsidian", streamID, 0.75, f)
    layouts.place("Stream Deck",      streamID, { x=f.x,    y=f.y, w=halfW, h=f.h })
    layouts.place("Elgato Wave Link", streamID, { x=rightX, y=f.y, w=halfW, h=f.h })
  end
end

function M.applyCatchAll(_, spaces)
  local config = require("config")
  local mainID = spaces.id("main")
  if not mainID then return end
  for _, w in ipairs(hs.window.allWindows()) do
    local app = w:application() and w:application():name() or ""
    if not config.managedApps[app] then
      hs.spaces.moveWindowToSpace(w, mainID)
    end
  end
end

return M
