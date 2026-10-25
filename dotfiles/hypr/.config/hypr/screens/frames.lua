-- Floating windows on the gaming workspace, which Hyprland only keeps the size of: their last frame is saved on close and reapplied on open.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")

-- Keyed by title too, since Steam's main window, friends list and popups share one class.
local function key(w)
  local title = w.title or ""
  if title ~= "" and w.class and w.workspace and w.workspace.name == C.gaming_workspace then
    return w.class .. "|" .. title
  end
end

local function load(class)
  local row = U.load_tsv("frames")[class]
  local x, y, w, h = row and tonumber(row[1]), row and tonumber(row[2]), row and tonumber(row[3]), row and tonumber(row[4])
  if x and y and w and h then return { x = x, y = y, w = w, h = h } end
end

local function save(class, frame)
  local frames = U.load_tsv("frames")
  local row = { tostring(frame.x), tostring(frame.y), tostring(frame.w), tostring(frame.h) }
  if table.concat(frames[class] or {}, "\t") == table.concat(row, "\t") then return end
  frames[class] = row
  U.save_tsv("frames", frames)
end

local applied = {}

local function restore(w)
  local class = key(w)
  if not class or applied[w.address] or not w.floating then return end
  local frame = load(class)
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
