---@meta
-- Types for the Hammerspoon APIs our macOS config uses; Hammerspoon only generates full annotations on a Mac (EmmyLua.spoon).

---@class hs.geometry.rect
---@field x number
---@field y number
---@field w number
---@field h number

---@class hs.screen
local screen_class = {}
---@return hs.geometry.rect
function screen_class:frame() end

---@class hs.window
local window_class = {}
---@param rect hs.geometry.rect
function window_class:setFrame(rect) end
---@return hs.screen
function window_class:screen() end

---@class hs.application
local application_class = {}
---@param allWindows? boolean
---@return boolean
function application_class:activate(allWindows) end

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
  },
  window = {
    ---@return hs.window?
    focusedWindow = function() end,
  },
  geometry = {
    ---@param x number
    ---@param y number
    ---@param w number
    ---@param h number
    ---@return hs.geometry.rect
    rect = function(x, y, w, h) end,
  },
  eventtap = {
    ---@param mods string[]
    ---@param key string
    ---@param delay? integer microseconds
    keyStroke = function(mods, key, delay) end,
  },
  hotkey = {
    ---@param mods string[]
    ---@param key string
    ---@param fn fun()
    ---@return hs.hotkey
    bind = function(mods, key, fn) end,
  },
}
