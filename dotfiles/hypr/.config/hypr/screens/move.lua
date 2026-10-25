-- Actions bound to keys: position a window, send it to another screen or workspace, open the menu on main.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")
local T = require("hypr.screens.top")
local S = require("hypr.screens.side")

local M = {}

function M.arrow(dir)
  return function()
    local w = hl.get_active_window()
    if not w then return end
    if U.on_side(w) then
      S.step(w, dir)
    elseif w.workspace and w.workspace.name == C.top_workspace and not w.floating and (dir == "left" or dir == "right") then
      T.join(w, dir)
    else
      hl.dispatch(hl.dsp.window.move({ direction = dir, window = w }))
    end
  end
end

-- The screen whose centre lies furthest in the arrow's direction from this one, preferring the closest on the cross axis.
local function neighbour(from, dir)
  local fa = U.area(from)
  local fx, fy = fa.x + fa.w / 2, fa.y + fa.h / 2
  local best, best_score
  for _, m in ipairs(hl.get_monitors()) do
    if m ~= from then
      local a = U.area(m)
      local dx, dy = a.x + a.w / 2 - fx, a.y + a.h / 2 - fy
      local along = ({ left = -dx, right = dx, up = -dy, down = dy })[dir]
      local across = (dir == "left" or dir == "right") and math.abs(dy) or math.abs(dx)
      if along > 0 then
        local score = along + across * 2
        if not best_score or score < best_score then best, best_score = m, score end
      end
    end
  end
  return best
end

local function relocate(w, workspace)
  local from_side = U.on_side(w)
  if w.group then hl.dispatch(hl.dsp.window.move({ out_of_group = true, window = w })) end
  hl.dispatch(hl.dsp.window.move({ workspace = workspace, window = w }))
  -- The portrait screen floats everything into slots; elsewhere the window should tile again.
  if from_side and not C.side_workspaces[workspace] and not U.transient(w) then
    hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
  end
end

function M.send(dir)
  return function()
    local w = hl.get_active_window()
    if not w or not w.monitor then return end
    local target = neighbour(w.monitor, dir)
    local workspace = target and target.active_workspace
    if workspace then relocate(w, workspace.name) end
  end
end

function M.send_to(workspace)
  return function()
    local w = hl.get_active_window()
    if w then relocate(w, workspace) end
  end
end

-- The shell opens its menu on the focused monitor, so focusing main first keeps it there.
function M.menu()
  local main = hl.get_monitor(C.main)
  if main then hl.dispatch(hl.dsp.focus({ monitor = main.name })) end
  hl.exec_cmd("omarchy-menu toggle")
end

return M
