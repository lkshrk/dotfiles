package.path = "dotfiles/hypr/.config/?.lua;" .. package.path

local active, calls, joins, handlers = nil, {}, {}, {}
local monitors = {
  { name = "main", x = -1920, y = 100, width = 1920, height = 1200, scale = 1, transform = 0 },
  { name = "portrait", x = 0, y = 0, width = 2560, height = 1440, scale = 1.25, transform = 1 },
  { name = "top", x = 0, y = -1080, width = 3840, height = 2160, scale = 2, transform = 0 },
}
for _, monitor in ipairs(monitors) do
  monitor.reserved = { left = 0, top = 30, right = 0, bottom = 0 }
end

local function dispatcher(kind)
  return function(args) return { kind = kind, args = args } end
end

hl = {
  on = function(event, fn) handlers[event] = fn end,
  timer = function() end,
  get_windows = function() return {} end,
  get_active_window = function() return active end,
  get_config = function() return 2 end,
  get_monitor = function(name)
    for _, monitor in ipairs(monitors) do if monitor.name == name then return monitor end end
  end,
  dsp = { window = {
    move = dispatcher("move"), float = dispatcher("float"),
    resize = dispatcher("resize"), alter_zorder = dispatcher("zorder"),
    fullscreen_state = dispatcher("fullscreen_state"), center = dispatcher("center"),
  } },
  dispatch = function(command)
    calls[#calls + 1] = command
    local args, w = command.args, command.args.window or active
    if command.kind == "fullscreen_state" then w.fullscreen = args.internal
    elseif command.kind == "float" then w.floating = args.action == "enable"
    elseif command.kind == "resize" then w.size = { x = args.x, y = args.y }
    elseif command.kind == "move" then
      if args.out_of_group then w.group = nil
      elseif args.workspace then w.workspace = { name = args.workspace }
      else w.at = { x = args.x, y = args.y } end
    end
  end,
}

monitors[1].active_workspace = { name = "3" }
package.loaded["hypr.screens.config"] = {
  side = "portrait", main = "main", top_workspace = "10",
  homes = { kitty = "10" }, password_prompt = function() return false end, side_workspaces = {},
}
package.loaded["hypr.screens.top"] = {
  join = function(w, side)
    assert(not w.floating, "column entry must tile the window before joining a group")
    joins[#joins + 1] = { window = w, side = side }
  end,
  pick_side = function() return "left" end,
}
package.loaded["hypr.screens.side"] = {}
local U = require("hypr.screens.util")
local M = require("hypr.screens.move")

local function window(monitor, workspace)
  local area = U.area(monitor)
  return {
    monitor = monitor, workspace = { name = workspace or "1" }, fullscreen = 0, floating = false,
    at = { x = area.x + 2, y = area.y + 2 }, size = { x = area.w - 4, y = area.h - 4 },
  }
end

local function close(actual, expected, message)
  assert(math.abs(actual - expected) <= 1, message .. ": " .. actual .. " ~= " .. expected)
end

for _, monitor in ipairs(monitors) do
  local area = U.area(monitor)
  active = window(monitor)
  M.arrow("left")()
  assert(active.floating, "snapping a tiled window must float it on " .. monitor.name)
  close(active.at.x, area.x + 2, "left edge follows selected monitor")
  close(active.size.x, area.w / 2 - 4, "left half width")
  M.arrow("left")()
  close(active.size.x, area.w - 4, "repeating left restores full width")
  M.arrow("right")()
  close(active.at.x, area.x + math.floor(area.w / 2) + 2, "right half position")
  M.arrow("right")()
  close(active.size.x, area.w - 4, "repeating right restores full width")

  M.arrow("up")()
  close(active.at.y, area.y + 2, "first vertical stop starts at top")
  close(active.size.y, area.h / 3 - 4, "first vertical stop is one third")
  for _, stop in ipairs({ { 0, 2 }, { 1, 1 }, { 1, 2 }, { 2, 1 }, { 0, 3 } }) do
    M.arrow("down")()
    close(active.at.y, area.y + math.floor(area.h * stop[1] / 3) + 2, "vertical stop position")
    close(active.size.y, math.floor(area.h * (stop[1] + stop[2]) / 3)
      - math.floor(area.h * stop[1] / 3) - 4, "vertical stop height")
  end

  -- Arbitrary pre-snap geometry must never produce a rectangle below the monitor.
  active.at.y, active.size.y = area.y + area.h * 0.85, area.h * 0.65
  M.arrow("left")()
  assert(active.at.y + active.size.y + 2 <= area.y + area.h, "snap stays inside usable monitor area")
end

active = window(monitors[1])
local peer = window(monitors[1])
active.group = { active, peer }
calls = {}
M.arrow("left")()
assert(calls[1].kind == "move" and calls[1].args.out_of_group, "detach selected tab before floating")
assert(active.group == nil and active.floating and not peer.floating, "other group members stay tiled")

for _, mode in ipairs({ 2, 3 }) do
  active = window(monitors[1]); active.fullscreen, active.group = mode, {}
  calls = {}; M.arrow("left")()
  assert(#calls == 0 and active.group ~= nil, "fullscreen windows are untouched")
end
active = window(monitors[1]); active.fullscreen = 1
calls = {}; M.arrow("left")()
assert(calls[1].kind == "fullscreen_state" and active.fullscreen == 0, "maximized windows leave maximize first")
assert(active.floating, "maximized windows snap after leaving maximize")

active = window(monitors[1]); active.monitor = nil
calls = {}; M.arrow("left")(); assert(#calls == 0, "missing monitor is harmless")
active = nil; M.arrow("left")(); assert(#calls == 0, "missing focused window is harmless")

for _, side in ipairs({ "left", "right" }) do
  active = window(monitors[3], "10"); active.floating = true
  local before = #joins
  M.column(side)()
  assert(#joins == before + 1 and joins[#joins].side == side, "snapped window rejoins requested column")
end
active = window(monitors[3], "10"); active.floating, active.group = true, {}
calls = {}; M.column("left")()
assert(calls[1].kind == "move" and calls[1].args.out_of_group, "detach a floating group member before tiling")
active = window(monitors[1]); calls = {}
local before = #joins
M.column("left")()
assert(#calls == 0 and #joins == before, "column shortcuts ignore other workspaces")
active = window(monitors[3], "10"); active.fullscreen = 2
M.column("right")()
assert(#calls == 0 and #joins == before, "column shortcuts protect fullscreen")
active = window(monitors[3], "10"); active.fullscreen = 1
calls = {}; M.column("right")()
assert(calls[1].kind == "fullscreen_state" and calls[1].args.window == active, "column leaves maximize first")
assert(active.fullscreen == 0 and #joins == before + 1 and joins[#joins].side == "right", "maximized window joins column")

require("hypr.screens.windows")
local popup = window(monitors[3], "10"); popup.class, popup.address = "popup", "0x1"
calls = {}; handlers["window.open"](popup)
assert(popup.floating and popup.workspace.name == "3", "top-screen popup floats onto main's active workspace")
assert(calls[#calls].kind == "center" and calls[#calls].args.window == popup, "popup is centered on main")
local app = window(monitors[3], "10"); app.class = "kitty"
before = #joins; handlers["window.open"](app)
assert(not app.floating and #joins == before + 1, "homed app on the top screen keeps its column")

print("ok: snapping on three monitor geometries, vertical cycles, groups, fullscreen, maximize, columns, and top-screen popups")
