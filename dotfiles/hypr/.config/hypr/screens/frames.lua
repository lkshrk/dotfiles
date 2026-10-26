-- Free floating windows, which Hyprland only keeps the size of: their last frame is saved and reapplied on open.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")
local D = require("hypr.screens.decide")

local applied, user_moved, left = {}, {}, {}

-- After a window closes, Hyprland reports focus with a freed window whose fields are all nil.
local function live(w)
  return w ~= nil and w.address ~= nil
end

local function in_scope(w)
  return live(w) and w.mapped and w.floating and (w.fullscreen or 0) == 0 and w.workspace ~= nil
    and not w.workspace.special and w.monitor ~= nil and not U.layout_placed(w) and not U.transient(w)
end

local function multi(w)
  return C.multi_window[w.class] == true
end

local function write(frames)
  U.save_tsv("frames", D.prune(frames, os.time(), C.frame_max_age_days * 86400))
end

local function put(w, frame)
  hl.dispatch(hl.dsp.window.resize({ x = frame.w, y = frame.h, window = w }))
  hl.dispatch(hl.dsp.window.move({ x = frame.x, y = frame.y, window = w }))
end

-- Keyed by title first, since Steam's main window, friends list and popups share one class; the app key covers changing titles.
local function place(w)
  if applied[w.address] or not in_scope(w) then return end
  local keys = {}
  local title_key = D.title_key(w.class, w.title)
  if title_key then keys[#keys + 1] = title_key end
  if D.app_frame_allowed(U.role(w.address), multi(w)) then keys[#keys + 1] = D.app_key(w.class) end
  if #keys == 0 then return end
  local frames = U.load_tsv("frames")
  local area = U.area(w.monitor)
  for _, key in ipairs(keys) do
    local frame = D.frame(frames[key])
    if frame and D.fits(frame, area) then
      applied[w.address] = frame
      put(w, frame)
      frames[key][5] = tostring(os.time())
      write(frames)
      return
    end
  end
end

local function remember(w)
  if not in_scope(w) or not U.settled(w.address) then return end
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
  local frames, changed = U.load_tsv("frames"), false
  for _, key in ipairs(keys) do
    local old = D.frame(frames[key])
    if not old or D.drifted(old, frame.x, frame.y, frame.w, frame.h) then
      frames[key] = D.row(frame, now)
      changed = true
    end
  end
  if changed then write(frames) end
end

-- X11 launchers place themselves after mapping, so the frame goes on once that has settled, and again if the app moved it later.
hl.on("window.open", function(w)
  local address = w.address
  hl.timer(function()
    local target = hl.get_window("address:" .. address)
    if target and target.mapped then place(target) end
  end, { timeout = C.frame_open_delay_ms, type = "oneshot" })
  hl.timer(function()
    local target = hl.get_window("address:" .. address)
    if not target or not target.mapped then return end
    local frame = applied[address]
    if not frame then return place(target) end
    local x, y = U.xy(target.at)
    local width, height = U.xy(target.size)
    if not user_moved[address] and D.drifted(frame, x, y, width, height) then put(target, frame) end
  end, { timeout = C.settle_ms, type = "oneshot" })
end)

hl.on("window.title", function(w)
  if live(w) and w.mapped then place(w) end
end)

-- A window that was waiting beside an older one gets the app frame once it turns out to be the main window.
U.on_role(function(w, role)
  if role == "main" and U.settled(w.address) then place(w) end
end)

-- Hyprland has no move or resize event; a window is moved while focused, so leaving it saves the frame.
local focused

hl.on("window.active", function(w)
  if not live(w) then w = nil end
  if focused and (not w or focused ~= w.address) then
    left[focused] = true
    local previous = hl.get_window("address:" .. focused)
    if previous and previous.mapped then remember(previous) end
  end
  if w and left[w.address] then user_moved[w.address] = true end
  focused = w and w.address or nil
end)

hl.on("window.close", function(w)
  if not live(w) then return end
  remember(w)
  applied[w.address], user_moved[w.address], left[w.address] = nil, nil, nil
  if focused == w.address then focused = nil end
end)

-- Windows can vanish without a clean close (a killed Wine prefix), so the focused one is also saved periodically.
hl.timer(function()
  local w = hl.get_active_window()
  if live(w) then remember(w) end
end, { timeout = C.frame_snapshot_ms, type = "repeat" })
