-- Free floating windows, which Hyprland only keeps the size of: their last frame is saved and turned into a window rule.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")
local D = require("hypr.screens.decide")

local F = {}

-- After a window closes, Hyprland reports focus with a freed window whose fields are all nil.
local function live(w)
  return w ~= nil and w.address ~= nil
end

local function in_scope(w, closing)
  return live(w) and (closing or w.mapped) and w.floating and (w.fullscreen or 0) == 0 and w.workspace ~= nil
    and not w.workspace.special and not U.layout_placed(w) and not U.transient(w)
end

local function multi(w)
  return C.multi_window[w.class] == true
end

local function monitors()
  local list = {}
  for _, m in ipairs(hl.get_monitors()) do
    local width, height = m.width / m.scale, m.height / m.scale
    if m.transform % 2 == 1 then width, height = height, width end
    list[#list + 1] = { name = m.name, x = m.x, y = m.y, w = width, h = height }
  end
  return list
end

local function split(key)
  local bar = key:find("|", 1, true)
  local title = key:sub(bar + 1)
  return key:sub(1, bar - 1), title ~= "" and title or nil
end

-- Rule names are unique per creation, since a redefined rule keeps its place and the newest rule wins a conflict.
local rules, made = {}, 0

local function drop(key)
  if not rules[key] then return end
  hl.window_rule({ name = rules[key], enabled = false, match = { class = "^$" } })
  rules[key] = nil
end

local function create(key, frame, mons)
  local class, title = split(key)
  local monitor = D.monitor_for(frame, mons)
  if not monitor then return drop(key) end
  local spec = D.frame_rule(class, title, frame, monitor)
  if rules[key] then
    spec.name = rules[key]
  else
    made = made + 1
    spec.name = "frames-" .. made
    rules[key] = spec.name
  end
  hl.window_rule(spec)
end

-- A title frame must win over its app's frame, so a new app rule is followed by fresh copies of that app's title rules.
local function register(key, frames, mons)
  local frame = D.frame(frames[key])
  if not frame then return drop(key) end
  local class, title = split(key)
  local fresh_app = title == nil and rules[key] == nil
  create(key, frame, mons)
  if not fresh_app then return end
  for other in pairs(frames) do
    local other_class, other_title = split(other)
    if other_class == class and other_title then
      drop(other)
      local other_frame = D.frame(frames[other])
      if other_frame then create(other, other_frame, mons) end
    end
  end
end

local function write(frames)
  local kept = D.prune(frames, os.time(), C.frame_max_age_days * 86400)
  for key in pairs(rules) do
    if not kept[key] then drop(key) end
  end
  U.save_tsv("frames", kept)
  return kept
end

local function remember(w, closing)
  if not in_scope(w, closing) or not U.settled(w.address) then return end
  local x, y = U.xy(w.at)
  local width, height = U.xy(w.size)
  if width <= 0 or height <= 0 then return end
  local frame, now = { x = x, y = y, w = width, h = height }, os.time()
  local keys = {}
  local title_key = D.title_key(w.class, w.title)
  if title_key then keys[#keys + 1] = title_key end
  if D.may_save_app(U.role(w.address), multi(w), U.age_ms(w.address), C.remember_after_ms) then
    keys[#keys + 1] = D.app_key(w.class)
  end
  local frames, changed = U.load_tsv("frames"), {}
  for _, key in ipairs(keys) do
    local old = D.frame(frames[key])
    if not old or D.drifted(old, frame.x, frame.y, frame.w, frame.h) then
      frames[key] = D.row(frame, now)
      changed[#changed + 1] = key
    end
  end
  if #changed == 0 then return end
  frames = write(frames)
  local mons = monitors()
  for _, key in ipairs(changed) do register(key, frames, mons) end
end

-- App rules first, so every title rule is created after the app rule it must override.
local function load_rules()
  local frames, mons = U.load_tsv("frames"), monitors()
  for key in pairs(frames) do
    if select(2, split(key)) == nil then register(key, frames, mons) end
  end
  for key in pairs(frames) do
    if select(2, split(key)) ~= nil then register(key, frames, mons) end
  end
end

load_rules()

-- Windows opened meanwhile keep their own size; reloading recreates the dropped rules in app-then-title order.
function F.suspend(class, ms)
  local dropped = false
  for key in pairs(rules) do
    if split(key) == class then
      drop(key)
      dropped = true
    end
  end
  if dropped then hl.timer(load_rules, { timeout = ms, type = "oneshot" }) end
end

-- A matching rule placed the window, so its row counts as used.
hl.on("window.open", function(w)
  if not live(w) then return end
  local frames, now, used = U.load_tsv("frames"), tostring(os.time()), false
  for _, key in ipairs({ D.title_key(w.class, w.title), not multi(w) and D.app_key(w.class) or nil }) do
    if frames[key] then
      frames[key][5] = now
      used = true
    end
  end
  if used then write(frames) end
end)

-- Hyprland has no move or resize event; a window is moved while focused, so leaving it saves the frame.
local focused

hl.on("window.active", function(w)
  if not live(w) then w = nil end
  if focused and (not w or focused ~= w.address) then
    local previous = hl.get_window("address:" .. focused)
    if previous and previous.mapped then remember(previous) end
  end
  focused = w and w.address or nil
end)

hl.on("window.close", function(w)
  if not live(w) then return end
  remember(w, true)
  if focused == w.address then focused = nil end
end)

-- Windows can vanish without a clean close (a killed Wine prefix), so the focused one is also saved periodically.
hl.timer(function()
  local w = hl.get_active_window()
  if live(w) then remember(w) end
end, { timeout = C.frame_snapshot_ms, type = "repeat" })

return F
