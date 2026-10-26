-- Window and geometry helpers shared by the screen modules.
local C = require("hypr.screens.config")
local D = require("hypr.screens.decide")

local U = {}

-- True while code moves windows itself, so the workspace-change handler leaves them alone.
U.state = { placing = false }

function U.app(w)
  local class = w.class or ""
  if class:match("^steam_app_%d+$") then return "steam" end
  -- Chatterino's X11 class is bare "chatterino"; its Wayland app id is the reverse-DNS one.
  if class == "chatterino" then return "com.chatterino.chatterino" end
  return class
end

function U.has_tag(w, tag)
  for _, t in ipairs(type(w.tags) == "table" and w.tags or {}) do
    if t == tag or t == tag .. "*" then return true end
  end
  return false
end

function U.transient(w)
  return U.has_tag(w, "dialog") or U.has_tag(w, "pip") or U.has_tag(w, "floating-window")
    or (w.class or ""):match("^org%.omarchy%.") ~= nil or U.has_tag(w, "secondary") or U.has_tag(w, "tray-menu")
end

-- Workspace layout or slots place these windows; remembered frames are for the rest.
function U.layout_placed(w)
  local name = w.workspace and w.workspace.name
  return not w.floating or C.side_workspaces[name] ~= nil or name == C.top_workspace
end

local roles, opened, settled, role_fns, generation = {}, {}, {}, {}, {}

function U.role(address) return roles[address] end
function U.settled(address) return settled[address] == true end
function U.on_role(fn) role_fns[#role_fns + 1] = fn end

function U.age_ms(address)
  local t = opened[address]
  return t and (os.time() - t) * 1000 or nil
end

local function classify(w)
  local others = {}
  for _, o in ipairs(hl.get_windows()) do
    if o.mapped and o.address ~= w.address then
      others[#others + 1] = { address = o.address, class = o.class, stable_id = o.stable_id, transient = U.transient(o) }
    end
  end
  return D.role(w, others, C.multi_window[w.class])
end

local function announce(w, role)
  roles[w.address] = role
  for _, fn in ipairs(role_fns) do fn(w, role) end
end

-- The first window of an app is decided at open; a window opened beside an older one waits, since the older may be a closing splash.
-- Addresses are reused after a window closes, so each timer only acts on the open it was started for.
hl.on("window.open", function(w)
  local address = w.address
  local gen = (generation[address] or 0) + 1
  generation[address], opened[address], settled[address] = gen, os.time(), nil
  if classify(w) == "main" then announce(w, "main") else roles[address] = "pending" end
  hl.timer(function()
    if generation[address] ~= gen then return end
    local target = hl.get_window("address:" .. address)
    if not target or not target.mapped then return end
    settled[address] = true
    if roles[address] == "pending" then announce(target, classify(target)) end
  end, { timeout = C.settle_ms, type = "oneshot" })
end)

-- Cleared after the other close handlers have run, so frames.lua can still save the closing window.
hl.on("window.close", function(w)
  if not w or not w.address then return end
  local address, gen = w.address, generation[w.address]
  hl.timer(function()
    if generation[address] ~= gen then return end
    roles[address], opened[address], settled[address] = nil, nil, nil
  end, { timeout = 1, type = "oneshot" })
end)

-- A config reload starts with empty tables; windows already open count as long settled.
-- Counted, not ipairs: omarchy-menu-keybindings runs this config against a stub whose every index is non-nil.
local open_windows = hl.get_windows()
for i = 1, #open_windows do
  local w = open_windows[i]
  if w.mapped and w.address then
    generation[w.address], settled[w.address] = 1, true
    opened[w.address] = os.time() - math.ceil(C.remember_after_ms / 1000)
    roles[w.address] = classify(w)
  end
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

local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hypr-screens/"

-- Small tab-separated state files keyed by their first field.
function U.load_tsv(name)
  local rows = {}
  local f = io.open(state_dir .. name, "r")
  if not f then return rows end
  for line in f:lines() do
    local fields = {}
    for field in (line .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = field end
    if #fields > 1 then rows[table.remove(fields, 1)] = fields end
  end
  f:close()
  return rows
end

-- No mkdir: blocking on a child process inside the compositor can stall it; setup creates the directory.
function U.save_tsv(name, rows)
  local f = io.open(state_dir .. name, "w")
  if not f then return end
  for key, fields in pairs(rows) do f:write(key, "\t", table.concat(fields, "\t"), "\n") end
  f:close()
end

function U.on_side(w)
  local side = hl.get_monitor(C.side)
  return w.floating and w.monitor and side and w.monitor.name == side.name
end

return U
