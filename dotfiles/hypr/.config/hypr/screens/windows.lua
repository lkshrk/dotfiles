-- Where new and moved windows go: slots, columns, floating extra windows, and putting everything back.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")
local T = require("hypr.screens.top")
local S = require("hypr.screens.side")

local W = {}

function W.arrive(w)
  if U.state.placing or not w or not w.workspace or U.transient(w) then return end
  local workspace = w.workspace.name
  if workspace == C.top_workspace then
    hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
    T.join(w, T.pick_side(w))
  elseif C.side_workspaces[workspace] then
    S.place(w)
  end
end

-- Dialog shape follows the screen width, so it stays landscape on the portrait screen too.
local function dialog_box(a)
  local width = math.floor(a.w * (a.w > a.h and 0.6 or 0.9))
  local height = math.floor(math.min(a.h * 0.8, width * 0.85))
  return { x = math.floor(a.x + (a.w - width) / 2), y = math.floor(a.y + (a.h - height) / 2), w = width, h = height }
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
  U.frame(w, dialog_box(U.area(w.monitor)))
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
    W.arrive(w)
  end
end

hl.on("window.open", function(w)
  if C.password_prompt[w.class] then
    local main = hl.get_monitor(C.main)
    local target = main and main.active_workspace
    if target and w.workspace ~= target then
      hl.dispatch(hl.dsp.window.move({ workspace = target.name, window = w }))
    end
    hl.dispatch(hl.dsp.window.center({ window = w }))
    return
  end
  -- Free floating windows keep the frame they were last left at (frames.lua), so they skip slots and the dialog box.
  if w.floating and not U.layout_placed(w) then return end
  if w.class == "helium" then
    place_helium(w)
    focus_soon(w)
    return
  end
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
