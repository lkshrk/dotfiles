---@meta
-- Types for the Hammerspoon APIs our macOS config uses; Hammerspoon only generates full annotations on a Mac (EmmyLua.spoon).

---@class hs.geometry.rect
---@field x number
---@field y number
---@field w number
---@field h number

---@class hs.geometry.point
---@field x number
---@field y number

---@class hs.screen
local screen_class = {}
---@return hs.geometry.rect
function screen_class:frame() end
---@return string
function screen_class:name() end
---@return string
function screen_class:getUUID() end
---@return integer
function screen_class:id() end

---@class hs.window
local window_class = {}
---@return integer
function window_class:id() end
---@return string
function window_class:title() end
---@return hs.geometry.rect
function window_class:frame() end
---@param rect hs.geometry.rect
function window_class:setFrame(rect) end
---@param point hs.geometry.point
function window_class:setTopLeft(point) end
---@return hs.screen
function window_class:screen() end
---@return hs.application
function window_class:application() end
---@return boolean
function window_class:isStandard() end
function window_class:focus() end

---@class hs.application
local application_class = {}
---@return string
function application_class:name() end
---@return hs.window[]
function application_class:allWindows() end
---@param allWindows? boolean
---@return boolean
function application_class:activate(allWindows) end

---@class hs.window.filter
local filter_class = {}
---@param event string
---@param fn fun(win: hs.window, appName: string, event: string)
function filter_class:subscribe(event, fn) end

---@class hs.watcher
local watcher_class = {}
function watcher_class:start() end
function watcher_class:stop() end

---@class hs.notification
local notification_class = {}
function notification_class:send() end

---@class hs.hotkey
local hotkey_class = {}

hs = {
  application = {
    ---@param hint string
    ---@return hs.application?
    find = function(hint) end,
    ---@param name string
    ---@return boolean
    launchOrFocus = function(name) end,
    ---@return hs.application
    frontmostApplication = function() end,
  },
  window = {
    ---@return hs.window?
    focusedWindow = function() end,
    ---@return hs.window[]
    allWindows = function() end,
    filter = {
      windowCreated = "windowCreated",
      windowFocused = "windowFocused",
      ---@param fn boolean|fun(win: hs.window): boolean
      ---@return hs.window.filter
      new = function(fn) end,
    },
  },
  screen = {
    ---@return hs.screen
    primaryScreen = function() end,
    ---@return hs.screen[]
    allScreens = function() end,
    watcher = {
      ---@param fn fun()
      ---@return hs.watcher
      new = function(fn) end,
    },
  },
  spaces = {
    ---@param win hs.window|integer
    ---@param spaceID integer
    ---@return boolean
    moveWindowToSpace = function(win, spaceID) end,
    ---@param win hs.window|integer
    ---@return integer[]?
    windowSpaces = function(win) end,
    ---@param spaceID integer
    ---@return string? "user" or "fullscreen"
    spaceType = function(spaceID) end,
    ---@param screen? hs.screen|string
    ---@return integer[]?
    spacesForScreen = function(screen) end,
    ---@return integer
    focusedSpace = function() end,
    watcher = {
      ---@param fn fun(space: integer)
      ---@return hs.watcher
      new = function(fn) end,
    },
  },
  geometry = {
    ---@param x number
    ---@param y number
    ---@param w number
    ---@param h number
    ---@return hs.geometry.rect
    rect = function(x, y, w, h) end,
  },
  alert = {
    ---@param text string
    ---@param seconds? number
    show = function(text, seconds) end,
  },
  timer = {
    ---@param seconds number
    ---@param fn fun()
    doAfter = function(seconds, fn) end,
    ---@return integer nanoseconds
    absoluteTime = function() end,
  },
  eventtap = {
    ---@param mods string[]
    ---@param key string
    ---@param delay? integer microseconds
    keyStroke = function(mods, key, delay) end,
    ---@param point hs.geometry.point
    leftClick = function(point) end,
  },
  mouse = {
    ---@param point? hs.geometry.point
    ---@return hs.geometry.point
    absolutePosition = function(point) end,
  },
  hotkey = {
    ---@param mods string[]
    ---@param key string
    ---@param fn fun()
    ---@return hs.hotkey
    bind = function(mods, key, fn) end,
  },
  osascript = {
    ---@param source string
    ---@return boolean ok, any result, table descriptor
    applescript = function(source) end,
  },
  notify = {
    ---@param attributes table
    ---@return hs.notification
    new = function(attributes) end,
  },
}
