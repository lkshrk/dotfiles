-- Where new and moved windows go: slots, columns, floating extra windows, and putting everything back.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")
local T = require("hypr.screens.top")
local S = require("hypr.screens.side")

local W = {}

-- Windows taking another window's frame; the move event arrives after U.state.placing is reset.
local copying = {}

function W.arrive(w)
  if U.state.placing or not w or not w.workspace or U.transient(w) or copying[w.address] then return end
  local workspace = w.workspace.name
  if workspace == C.top_workspace then
    hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
    T.join(w, T.pick_side(w))
  elseif C.side_workspaces[workspace] then
    S.place(w)
  end
end

-- Hyprland settles focus after window.open handlers run, so focusing from inside them can be undone; focus once it has.
local function focus_soon(w)
  local address = w.address
  hl.timer(function()
    local target = hl.get_window("address:" .. address)
    if not target or not target.mapped then return end
    hl.dispatch(hl.dsp.focus({ window = target }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = target }))
  end, { timeout = 150, type = "oneshot" })
end

local function make_extra(w)
  hl.dispatch(hl.dsp.window.tag({ tag = "+secondary", window = w }))
  if w.group then hl.dispatch(hl.dsp.window.move({ out_of_group = true, window = w })) end
  hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
  hl.dispatch(hl.dsp.window.center({ window = w }))
  focus_soon(w)
end

-- Settings and other extra windows share the app's class, so class-based slots would give them the main window's place.
-- Proton games share their class with launchers left open beside them, so fullscreen and gaming windows never become extras.
U.on_role(function(w, role, promoted)
  if promoted then
    hl.dispatch(hl.dsp.window.tag({ tag = "-secondary", window = w }))
    W.arrive(hl.get_window("address:" .. w.address) or w)
    return
  end
  -- A window whose role waited for the settle time skipped its slot at open.
  if role == "main" then
    if U.settled(w.address) and w.workspace and C.homes[U.app(w)] == w.workspace.name then W.arrive(w) end
    return
  end
  if role ~= "extra" or U.transient(w) or not U.layout_placed(w) then return end
  if (w.fullscreen or 0) ~= 0 or (w.workspace and w.workspace.name == C.gaming_workspace) then return end
  make_extra(w)
end)

local function helium_home(w)
  return w.title == C.helium_main_title and C.helium_main_workspace or "6"
end

-- Helium sets a restored window's name a moment after opening it, so the window may need to move once its title arrives.
local function place_helium(w)
  local home = helium_home(w)
  if w.workspace and w.workspace.name == home then return end
  U.state.placing = true
  U.move_to(w, home)
  U.state.placing = false
  if home == C.helium_main_workspace then
    hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
  else
    W.arrive(hl.get_window("address:" .. w.address) or w)
  end
end

local function place_exact(w, x, y, width, height)
  hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
  hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = w }))
  hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = w }))
end

-- A new Helium window (Ctrl+N) takes the frame of the window it was opened from.
local function copy_helium(w, source)
  local x, y = U.xy(source.at)
  local width, height = U.xy(source.size)
  local workspace = source.workspace and source.workspace.name
  local address, from = w.address, source.address
  copying[address] = true
  hl.timer(function() copying[address] = nil end, { timeout = 1000, type = "oneshot" })
  hl.timer(function()
    local new = hl.get_window("address:" .. address)
    if not new or not new.mapped then return end
    if workspace then
      U.state.placing = true
      U.move_to(new, workspace)
      U.state.placing = false
    end
    if (new.fullscreen or 0) ~= 0 then
      hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = new }))
    end
    local src = hl.get_window("address:" .. from)
    -- A workspace holds one fullscreen window, so a maximized source floats at its frame and hands the mode to the new window.
    if src and src.mapped and (src.fullscreen or 0) ~= 0 and src.workspace and src.workspace.name == workspace then
      local mode = src.fullscreen
      local sx, sy = U.xy(src.at)
      local sw, sh = U.xy(src.size)
      hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = src }))
      place_exact(src, sx, sy, sw, sh)
      hl.dispatch(hl.dsp.window.fullscreen_state({ internal = mode, client = mode, window = new }))
    else
      place_exact(new, x, y, width, height)
    end
    hl.dispatch(hl.dsp.focus({ window = new }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = new }))
  end, { timeout = 120, type = "oneshot" })
end

-- When each Helium window last had focus; a new window under the cursor can pull focus elsewhere (a game) before window.open.
local helium_focus, helium_seq, focused_helium = {}, 0, nil
hl.on("window.active", function(w)
  helium_seq = helium_seq + 1
  if focused_helium then helium_focus[focused_helium] = { seq = helium_seq, t = os.time() } end
  focused_helium = w and w.address and w.class == "helium" and w.address or nil
  if focused_helium then helium_focus[focused_helium] = { seq = helium_seq, t = os.time() } end
end)

-- Session restore opens several windows at once, so only a settled Helium window counts as the source.
local function helium_source(w)
  helium_focus[w.address] = nil
  local best, best_seq = nil, -1
  for address, seen in pairs(helium_focus) do
    local fresh = address == focused_helium or os.time() - seen.t <= 2
    if fresh and seen.seq > best_seq then
      local candidate = hl.get_window("address:" .. address)
      if candidate and candidate.mapped and candidate.class == "helium" and U.settled(address) then
        best, best_seq = candidate, seen.seq
      end
    end
  end
  return best
end

-- Popups and prompts always ask on the main screen's current workspace, whichever screen opened them.
local function to_main(w)
  local main = hl.get_monitor(C.main)
  local target = main and main.active_workspace
  if target and (not w.workspace or w.workspace.name ~= target.name) then
    hl.dispatch(hl.dsp.window.move({ workspace = target.name, window = w }))
  end
  hl.dispatch(hl.dsp.window.center({ window = w }))
end

-- Workspace 1 collects tiled apps without a home; floating ones are popups and go to the main screen.
local function collect(w)
  if (w.fullscreen or 0) ~= 0 or not w.workspace or w.workspace.special then return end
  if w.floating or U.has_tag(w, "dialog") then
    to_main(w)
    focus_soon(w)
    return
  end
  if U.transient(w) or w.workspace.name == "1" then return end
  local active = hl.get_active_workspace()
  local follow = active ~= nil and active.name == w.workspace.name
  hl.dispatch(hl.dsp.window.move({ workspace = "1", window = w, follow = follow }))
end

-- Hyprland floats popups (share picker, fixed-size windows) only after window.open on some layouts, so decide once it has.
local function collect_soon(w)
  local address = w.address
  hl.timer(function()
    local now = hl.get_window("address:" .. address)
    if now and now.mapped then collect(now) end
  end, { timeout = 120, type = "oneshot" })
end

hl.on("window.open", function(w)
  if C.password_prompt(w.class) then
    to_main(w)
    return
  end
  if w.class == "helium" then
    local source = helium_source(w)
    if source then
      copy_helium(w, source)
    else
      place_helium(w)
      focus_soon(w)
    end
    return
  end
  -- Free floating windows keep the frame they were last left at (frames.lua), so they skip slots and the dialog box.
  if w.floating and not U.layout_placed(w) then return end
  -- Only an app that lives on this workspace takes a slot or column; anything else is a popup or gets collected.
  if not w.workspace or C.homes[U.app(w)] ~= w.workspace.name then
    -- The columns layout tiles everything, so Hyprland never floats a popup there on its own.
    if w.workspace and w.workspace.name == C.top_workspace then
      hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
      to_main(w)
      focus_soon(w)
    else
      collect_soon(w)
    end
    return
  end
  -- A second window of the app may be a settings popup; on_role places it once its role is known.
  if U.role(w.address) == "pending" then return end
  W.arrive(w)
end)

hl.on("window.move_to_workspace", function(w) W.arrive(w) end)

-- Only the late "Main" title moves a window; other titles change with every tab and must not undo a manual move.
hl.on("window.title", function(w)
  if w and w.class == "helium" and w.mapped and w.title == C.helium_main_title then place_helium(w) end
end)

local function home_of(w)
  local name = U.app(w)
  if name == "helium" then return helium_home(w) end
  return C.homes[name] or (not w.floating and "1" or nil)
end

-- Called by scripts/focus-app through hyprctl eval when an app key picks a hidden window, like a Dock click on macOS.
function unhide_window(address)
  local w = hl.get_window("address:" .. address)
  if not w or not w.mapped then return end
  local home = home_of(w) or "1"
  U.state.placing = true
  U.move_to(w, home)
  U.state.placing = false
  W.arrive(hl.get_window("address:" .. address) or w)
end

function W.place_all()
  local last = {}
  U.state.placing = true
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped and w.workspace and not w.workspace.special and not U.transient(w) then
      local home = home_of(w)
      if home then
        U.move_to(w, home)
        if not C.floating_workspaces[home] then
          hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
        end
        last[#last + 1] = w
      end
    end
  end
  U.state.placing = false
  table.sort(last, function(a, b)
    return not (C.slots[U.app(a)] or {}).above and (C.slots[U.app(b)] or {}).above or false
  end)
  for _, w in ipairs(last) do W.arrive(w) end
end

return W
