-- Replaces Omarchy's per-monitor workspace blocks, which renumber and move the fixed workspaces screens/config.lua pins.
require("default.hypr.helpers")

local M = {}

function M.focus(slot)
  return hl.dsp.focus({ workspace = tostring(slot) })
end

function M.move_window(slot, follow)
  return hl.dsp.window.move({ workspace = tostring(slot), follow = follow ~= false })
end

function M.move_to_monitor(direction)
  return hl.dsp.workspace.move({ monitor = direction })
end

function M.move_window_to_monitor(direction)
  return hl.dsp.window.move({ monitor = direction })
end

o.workspaces = M

return M
