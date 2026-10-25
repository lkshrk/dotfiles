-- Window and geometry helpers shared by the screen modules.
local C = require("hypr.screens.config")

local U = {}

-- True while code moves windows itself, so the workspace-change handler leaves them alone.
U.state = { placing = false }

function U.app(w)
  local class = w.class or ""
  if class:match("^steam_app_%d+$") then return "steam" end
  return class
end

function U.has_tag(w, tag)
  for _, t in ipairs(type(w.tags) == "table" and w.tags or {}) do
    if t == tag or t == tag .. "*" then return true end
  end
  return false
end

local function splash(w)
  local pattern = C.splash_titles[w.class or ""]
  return pattern ~= nil and (w.title or ""):match(pattern) ~= nil
end

local function primary_of(class)
  local first
  for _, w in ipairs(hl.get_windows({ class = class })) do
    if w.mapped and w.class == class and not splash(w) and (not first or w.stable_id < first.stable_id) then first = w end
  end
  return first
end

function U.secondary(w)
  if U.has_tag(w, "secondary") then return true end
  if C.multi_window[w.class] or splash(w) then return false end
  local first = primary_of(w.class)
  return first ~= nil and first ~= w
end

function U.transient(w)
  return U.has_tag(w, "dialog") or U.has_tag(w, "pip") or U.has_tag(w, "floating-window")
    or (w.class or ""):match("^org%.omarchy%.") ~= nil or U.has_tag(w, "secondary")
end

function U.xy(v)
  if type(v) ~= "table" then return 0, 0 end
  return v.x or v[1] or 0, v.y or v[2] or 0
end

function U.area(monitor)
  local w, h = monitor.width, monitor.height
  if monitor.transform % 2 == 1 then w, h = h, w end
  w, h = w / monitor.scale, h / monitor.scale
  local r = monitor.reserved
  return {
    x = monitor.x + r.left, y = monitor.y + r.top,
    w = w - r.left - r.right, h = h - r.top - r.bottom,
  }
end

function U.cell(a, row, rows, col, cols)
  local x0, x1 = math.floor(a.w * col / 3), math.floor(a.w * (col + cols) / 3)
  local y0, y1 = math.floor(a.h * row / 3), math.floor(a.h * (row + rows) / 3)
  return { x = math.floor(a.x) + x0, y = math.floor(a.y) + y0, w = x1 - x0, h = y1 - y0 }
end

-- Floating borders are drawn outside the window, so inset by the border to keep it on screen.
function U.frame(w, box)
  local b = tonumber(hl.get_config("general.border_size")) or 0
  hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
  hl.dispatch(hl.dsp.window.resize({ x = box.w - 2 * b, y = box.h - 2 * b, window = w }))
  hl.dispatch(hl.dsp.window.move({ x = box.x + b, y = box.y + b, window = w }))
end

function U.move_to(w, workspace)
  if w.workspace and w.workspace.name == workspace then return end
  hl.dispatch(hl.dsp.window.move({ workspace = workspace, window = w, follow = false }))
end

function U.on_side(w)
  local side = hl.get_monitor(C.side)
  return w.floating and w.monitor and side and w.monitor.name == side.name
end

return U
