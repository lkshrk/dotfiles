-- Replaces Omarchy's per-monitor workspace blocks, which renumber and move the fixed workspaces screens/config.lua pins.
require("default.hypr.helpers")

local M = { slots = 10 }

local function action(fn, expression)
  o.bind_expressions[fn] = expression
  return fn
end

function M.workspace_id(_, slot)
  return slot
end

function M.focus(slot)
  return action(function()
    hl.dispatch(hl.dsp.focus({ workspace = tostring(slot) }))
  end, "o.workspaces.focus(" .. slot .. ")")
end

function M.move_window(slot, follow)
  return action(function()
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(slot), follow = follow ~= false }))
  end, "o.workspaces.move_window(" .. slot .. ", " .. tostring(follow ~= false) .. ")")
end

function M.move_to_monitor(direction)
  return action(function()
    hl.dispatch(hl.dsp.workspace.move({ monitor = direction }))
  end, string.format("o.workspaces.move_to_monitor(%q)", direction))
end

function M.move_window_to_monitor(direction)
  return action(function()
    hl.dispatch(hl.dsp.window.move({ monitor = direction }))
  end, string.format("o.workspaces.move_window_to_monitor(%q)", direction))
end

function M.reconcile() end

o.workspaces = M

return M
