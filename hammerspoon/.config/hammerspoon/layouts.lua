local spaces = require("spaces")
local M = {}

function M.findWindow(appName, spaceID)
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

function M.place(appName, spaceID, frame)
  local w = M.findWindow(appName, spaceID)
  if not w then return end
  w:setFrame(hs.geometry.rect(frame.x, frame.y, frame.w, frame.h))
end

function M.placeCenteredScaled(appName, spaceID, scale, screenFrame)
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

function M.placeCenteredBottomInRegion(appName, spaceID, region)
  local w = M.findWindow(appName, spaceID)
  if not w then return end
  local cf = w:frame()
  w:setTopLeft({
    x = region.x + (region.w - cf.w) / 2,
    y = region.y + region.h - cf.h,
  })
end

local function call(name)
  local config = require("config")
  local fn = config[name]
  if type(fn) == "function" then fn(M, spaces) end
end

function M.applyMainScreen()   call("applyMainScreen")   end
function M.applySecondScreen() call("applySecondScreen") end
function M.applyCatchAll()     call("applyCatchAll")     end

function M.applyAll()
  M.applyMainScreen()
  M.applySecondScreen()
  M.applyCatchAll()
end

return M
