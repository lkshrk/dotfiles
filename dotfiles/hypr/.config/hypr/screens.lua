-- Per-monitor layout; the modules in screens/ register their rules and handlers when loaded.
local W = require("hypr.screens.windows")
local M = require("hypr.screens.move")
require("hypr.screens.fullscreen")
require("hypr.screens.frames")

return {
  arrow = M.arrow,
  send = M.send,
  send_to = M.send_to,
  menu = M.menu,
  place_all = W.place_all,
}
