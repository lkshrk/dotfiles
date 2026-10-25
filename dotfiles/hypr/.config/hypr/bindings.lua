local C = require("hypr.screens.config")
-- If an update breaks the screens modules, only their bindings go dead; Hyprland's require returns {} on failure.
local M, W = require("hypr.screens.move"), require("hypr.screens.windows")
require("hypr.screens.fullscreen")
require("hypr.screens.frames")
if type(M.arrow) ~= "function" or type(W.place_all) ~= "function" then
  local noop = function() return function() end end
  M = { arrow = noop, send = noop, send_to = noop, menu = function() hl.exec_cmd("omarchy-menu toggle") end }
  W = { place_all = function() end }
end

-- keyd turns Caps Lock into this chord.
local HYPER = "SUPER + CTRL + ALT"
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

local function hyper(keys, description, dispatcher)
  o.bind(HYPER .. " + " .. keys, description, dispatcher)
end

local function focus(args)
  return scripts .. "/focus-app " .. args
end

-- Hyper + key enters the app at its most recent window and then steps through the rest; Shift sends the focused window to the app's workspace.
local function app(key, name, class, args)
  hyper(key, name, args)
  hyper("SHIFT + " .. key, "Send window to " .. name .. "'s workspace", M.send_to(C.homes[class]))
end

-- Omarchy's battery, calendar, time and weather notices sit on these Hyper keys; the app keys below take them, the bar keeps the info.
hl.unbind(HYPER .. " + B")
hl.unbind(HYPER .. " + D")
hl.unbind(HYPER .. " + T")
hl.unbind(HYPER .. " + W")
-- Reminders, zoom reset and laptop mirroring would otherwise sit on Caps next to the app keys.
hl.unbind(HYPER .. " + R")
hl.unbind(HYPER .. " + Z")
hl.unbind(HYPER .. " + DELETE")

app("B", "Helium", "helium", focus("'^helium$' omarchy-launch-browser"))
app("C", "Chatterino", "com.chatterino.chatterino", focus("chatterino chatterino"))
app("D", "Discord", "discord", focus("discord discord"))
app("E", "Editor", "dev.zed.Zed", focus("--order stable --title '\\.nvim\\.' zed zeditor"))
app("K", "Linear", "chrome-linear.app__-Default", os.getenv("HOME") .. "/.local/bin/webapp-focus https://linear.app")
app("N", "Obsidian", "md.obsidian.Obsidian", focus("--exclude-title '^Settings - ' '^md\\.obsidian\\.Obsidian$' obsidian"))
app("O", "OBS", "com.obsproject.Studio", focus("obsproject obs"))
app("V", "Brave", "brave-browser", focus("'^brave-browser$' brave"))
app("S", "Messengers", "signal", focus("'^(signal|org\\.telegram\\.desktop)$' signal-desktop"))
app("T", "Terminal", "foot", focus("--exclude-title '\\.nvim\\.' '^(foot|footclient|Alacritty|com\\.mitchellh\\.ghostty)$' xdg-terminal-exec"))
app("A", "ChatGPT", "chatgpt", focus("'^chatgpt$' chatgpt"))
app("SLASH", "Bitwarden", "Bitwarden", focus("'^bitwarden$' bitwarden-desktop"))
hyper("G", "Gaming workspace", hl.dsp.focus({ workspace = C.gaming_workspace }))
hyper("SHIFT + G", "Send window to the gaming workspace", M.send_to(C.gaming_workspace))
hyper("U", "Sound workspace", hl.dsp.focus({ workspace = C.homes.opendeck }))
hyper("SHIFT + U", "Send window to the sound workspace", M.send_to(C.homes.opendeck))

-- Arrows position the window (portrait: halves and thirds, top screen: column); Shift sends it to the screen that way.
-- Hyper already holds Super, Ctrl and Alt, so Shift is the only modifier left to tell the two apart.
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  local key = dir:upper()
  hyper(key, "Move window " .. dir, M.arrow(dir))
  hyper("SHIFT + " .. key, "Send window to the screen " .. dir, M.send(dir))
end
hyper("SHIFT + L", "Put every window back in place", W.place_all)
-- Super + F and Super + Alt + F only toggle their own mode; this leaves either.
hyper("F", "Normal size", hl.dsp.window.fullscreen_state({ internal = 0, client = 0 }))

-- Ctrl stays Ctrl for apps, so window management lives on Hyper as with skhd on the Mac; digits use keycodes so Shift does not turn them into symbols.
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  hyper(key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  hyper("SHIFT + " .. key, "Send window to workspace " .. workspace, M.send_to(tostring(workspace)))
end
hyper("W", "Close window", hl.dsp.window.close())
hyper("M", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hyper("Return", "Maximize", hl.dsp.window.fullscreen({ mode = "maximized" }))
hyper("J", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))
-- keyd leaves no key sending plain Super, so Omarchy's Super+drag is unreachable; Wine title bars cannot be dragged at all.
o.bind(HYPER .. " + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind(HYPER .. " + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })
-- Only floating windows can be pinned; the tag sends a window floated here back to tiling on unpin.
hyper("P", "Toggle stay on top", function()
  local w = hl.get_active_window()
  if not w then return end
  if w.pinned then
    hl.dispatch(hl.dsp.window.pin({ window = w }))
    for _, tag in ipairs(type(w.tags) == "table" and w.tags or {}) do
      if tag == "pinned-tiled" or tag == "pinned-tiled*" then
        hl.dispatch(hl.dsp.window.tag({ tag = "-pinned-tiled", window = w }))
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
      end
    end
    return
  end
  if not w.floating then
    hl.dispatch(hl.dsp.window.tag({ tag = "+pinned-tiled", window = w }))
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
  end
  hl.dispatch(hl.dsp.window.pin({ window = w }))
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
end)
hyper("SHIFT + P", "Pop window out (float & pin)", "omarchy-hyprland-window-pop")

-- Mac screenshot keys (code:12/13 are 3/4); Hyper + Shift + 3/4 still moves a window to workspace 3/4.
hl.unbind("SUPER + SHIFT + code:12")
hl.unbind("SUPER + SHIFT + code:13")
o.bind("SUPER + SHIFT + code:12", "Screenshot full screen to clipboard", "omarchy-capture-screenshot fullscreen copy")
o.bind("SUPER + SHIFT + code:13", "Screenshot region or window to clipboard", "omarchy-capture-screenshot smart copy")
o.bind("SUPER + CTRL + SHIFT + code:12", "Screenshot full screen to file and clipboard", "omarchy-capture-screenshot fullscreen")
o.bind("SUPER + CTRL + SHIFT + code:13", "Screenshot region or window to file and clipboard", "omarchy-capture-screenshot smart")

-- The Keychron sends Ctrl + Super + Q for Fn + L, the Mac lock key.
hl.unbind("SUPER + CTRL + Q")
o.bind("SUPER + CTRL + Q", "Lock and turn off monitors", "omarchy-system-lock && sleep 1 && omarchy-brightness-display off")

o.bind("SUPER + Q", "Quit application", scripts .. "/quit-app")
-- Omarchy's close-all drops every browser window but the last from its session; the menu's power entries quit apps whole instead.
hl.unbind("CTRL + ALT + DELETE")

hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Omarchy menu", M.menu)

-- keyd sends Cmd + H / Cmd + M here (see omarchy/keyd/common); hidden windows come back from the bar or the menu.
o.bind("SUPER + SHIFT + H", "Hide window", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Cmd sends Ctrl now, so apps get their native copy/paste and Omarchy's Super translation would only shadow physical Ctrl.
hl.unbind("SUPER + C")
hl.unbind("SUPER + V")
hl.unbind("SUPER + X")

-- Cmd + Tab arrives as Super + Tab (keyd's cmdtab layer); the submap keeps Super + Esc from opening the system menu.
hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")

local switching = false

local function switcher(action, leave)
  return function()
    if action == "commit" and not switching then return end
    switching = not leave
    hl.exec_cmd("omarchy-shell -q alttab " .. action)
    hl.dispatch(hl.dsp.submap(leave and "reset" or "alttab"))
  end
end

o.bind("SUPER + TAB", "Switch windows", switcher("next"))
o.bind("SUPER + SHIFT + TAB", "Switch windows backwards", switcher("prev"))
-- A quick tap can release Cmd before the submap is entered, so the release also commits outside it, but only mid-switch.
o.bind("SUPER + SUPER_L", "Finish window switch", switcher("commit", true), { release = true, transparent = true })

hl.define_submap("alttab", function()
  o.bind("SUPER + TAB", "Next window", switcher("next"))
  o.bind("SUPER + SHIFT + TAB", "Previous window", switcher("prev"))
  o.bind("SUPER + ESCAPE", "Cancel window switch", switcher("cancel", true))
  -- The release bind also covers a tap that ends before the overlay grabs the keyboard.
  o.bind("SUPER + SUPER_L", "Finish window switch", switcher("commit", true), { release = true, transparent = true })
  -- Adding Shift mid-switch steps backwards on the next Tab, so the Shift press itself must not reach the catchall.
  for _, shift in ipairs({ "Shift_L", "Shift_R" }) do
    o.bind("SUPER + " .. shift, "Hold Shift in window switch", function() end)
    o.bind("SUPER + SHIFT + " .. shift, "Hold Shift in window switch", function() end)
  end
  -- Any other key leaves the switcher, so a missed release can never strand the keyboard in this submap.
  o.bind("catchall", "Leave window switch", switcher("cancel", true))
end)
