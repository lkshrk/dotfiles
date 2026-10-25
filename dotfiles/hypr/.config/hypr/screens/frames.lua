-- Floating windows on the gaming workspace, which Hyprland only keeps the size of: their last frame is saved on close and reapplied on open.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")

local frames_file = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hypr-screens/frames"

-- Keyed by title too, since Steam's main window, friends list and popups share one class.
local function key(w)
  local title = w.title or ""
  if title ~= "" and w.class and w.workspace and w.workspace.name == C.gaming_workspace then
    return w.class .. "|" .. title
  end
end

local function load()
  local frames = {}
  local f = io.open(frames_file, "r")
  if not f then return frames end
  for line in f:lines() do
    local class, x, y, width, height = line:match("^(.-)\t(-?%d+)\t(-?%d+)\t(%d+)\t(%d+)$")
    if class then frames[class] = { x = tonumber(x), y = tonumber(y), w = tonumber(width), h = tonumber(height) } end
  end
  f:close()
  return frames
end

local function same(a, b)
  return a and b and a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

local function save(class, frame)
  local frames = load()
  if same(frames[class], frame) then return end
  frames[class] = frame
  -- No mkdir here: blocking on a child process from inside the compositor can stall it. setup creates the directory.
  local f = io.open(frames_file, "w")
  if not f then return end
  for c, b in pairs(frames) do f:write(c, "\t", b.x, "\t", b.y, "\t", b.w, "\t", b.h, "\n") end
  f:close()
end

local applied = {}

local function restore(w)
  local class = key(w)
  if not class or applied[w.address] or not w.floating then return end
  local frame = load()[class]
  if not frame then return end
  applied[w.address] = true
  hl.dispatch(hl.dsp.window.resize({ x = frame.w, y = frame.h, window = w }))
  hl.dispatch(hl.dsp.window.move({ x = frame.x, y = frame.y, window = w }))
end

local function remember(w)
  local class = key(w)
  if not class or not w.floating then return end
  local x, y = U.xy(w.at)
  local width, height = U.xy(w.size)
  if width > 0 and height > 0 then save(class, { x = x, y = y, w = width, h = height }) end
end

-- X11 launchers place themselves after mapping, so the frame goes on once that has settled.
hl.on("window.open", function(w)
  if not key(w) then return end
  local address = w.address
  hl.timer(function()
    local target = hl.get_window("address:" .. address)
    if target and target.mapped then restore(target) end
  end, { timeout = 500, type = "oneshot" })
end)

hl.on("window.title", function(w)
  if w and w.mapped then restore(w) end
end)

-- Hyprland has no move or resize event; a launcher is moved while focused, so leaving it saves the frame.
local focused

-- After a window closes, Hyprland reports focus with a freed window whose fields are all nil.
local function live(w)
  return w ~= nil and w.address ~= nil
end

hl.on("window.active", function(w)
  if not live(w) then w = nil end
  if focused and (not w or focused ~= w.address) then
    local previous = hl.get_window("address:" .. focused)
    if previous and previous.mapped then remember(previous) end
  end
  focused = w and key(w) and w.address or nil
end)

hl.on("window.close", function(w)
  if not live(w) then return end
  remember(w)
  applied[w.address] = nil
  if focused == w.address then focused = nil end
end)
