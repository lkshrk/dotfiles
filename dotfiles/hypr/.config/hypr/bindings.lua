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

-- Every listed binding is recorded here, so scripts/keybindings shows exactly this file, in this section order.
local SECTIONS = { "Apps", "Windows", "Workspaces", "Screens", "Capture", "Notifications", "System" }
local registry = {}
local omarchy_bind = o.bind

local function note(section, keys, description, dispatcher)
  registry[#registry + 1] = { section = section, keys = keys, description = description, dispatcher = dispatcher }
end

-- A nil section binds without a row of its own, for keys a note() row sums up.
local function bind(section, keys, description, dispatcher, opts)
  omarchy_bind(keys, description, dispatcher, opts)
  if section then note(section, keys, description, dispatcher) end
end

local function hyper(section, keys, description, dispatcher, opts)
  bind(section, HYPER .. " + " .. keys, description, dispatcher, opts)
end

local KEY_LABELS = {
  comma = ",", period = ".", SLASH = "/", ["code:20"] = "-", ["code:21"] = "=",
  ["mouse:272"] = "LEFT DRAG", ["mouse:273"] = "RIGHT DRAG",
  XF86PowerOff = "POWER", XF86Calculator = "CALCULATOR",
}

local function label(keys)
  local from, to = keys:find(HYPER, 1, true)
  if from then keys = keys:sub(1, from - 1) .. "HYPER" .. keys:sub(to + 1) end
  local parts = {}
  for raw in keys:gmatch("[^+]+") do
    local part = raw:match("^%s*(.-)%s*$")
    local code = tonumber(part:match("^code:(%d+)$") or "")
    if code and code >= 10 and code <= 19 then part = tostring((code - 9) % 10) end
    parts[#parts + 1] = KEY_LABELS[part] or part:upper()
  end
  return table.concat(parts, " + ")
end

function keybinds_list()
  local rank, order = {}, {}
  for i, section in ipairs(SECTIONS) do rank[section] = i end
  for i in ipairs(registry) do order[i] = i end
  table.sort(order, function(a, b)
    local ra, rb = rank[registry[a].section] or #SECTIONS + 1, rank[registry[b].section] or #SECTIONS + 1
    if ra ~= rb then return ra < rb end
    return a < b
  end)
  local rows = {}
  for _, i in ipairs(order) do
    local r = registry[i]
    rows[#rows + 1] = table.concat({ i, r.section, label(r.keys), r.description, r.dispatcher and "run" or "" }, "\t")
  end
  return table.concat(rows, "\n")
end

function keybinds_run(i)
  local d = registry[i] and registry[i].dispatcher
  if type(d) == "function" then
    d()
  elseif type(d) == "string" then
    hl.exec_cmd(d)
  elseif type(d) == "table" and d.omarchy then
    hl.exec_cmd("omarchy-launch-" .. d.omarchy)
  elseif d then
    hl.dispatch(d)
  end
end

-- Hyper + key enters the app at its most recent window and then steps through the rest; Shift sends the focused window to the app's workspace.
local function app(key, name, class, command)
  hyper("Apps", key, name, command)
  hyper(nil, "SHIFT + " .. key, "Send window to " .. name .. "'s workspace", M.send_to(C.homes[class]))
end

local function focus(args)
  return scripts .. "/focus-app " .. args
end

app("T", "Terminal", "foot", focus("--exclude-title '\\.nvim\\.' '^(foot|footclient|Alacritty|com\\.mitchellh\\.ghostty)$' xdg-terminal-exec"))
app("B", "Helium (browser)", "helium", focus("'^helium$' omarchy-launch-browser"))
app("V", "Brave (browser)", "brave-browser", focus("'^brave-browser$' brave"))
app("E", "Editor (Zed)", "dev.zed.Zed", focus("--order stable --title '\\.nvim\\.' zed zeditor"))
app("N", "Obsidian", "md.obsidian.Obsidian", focus("--exclude-title '^Settings - ' '^md\\.obsidian\\.Obsidian$' obsidian"))
app("K", "Linear", "chrome-linear.app__-Default", os.getenv("HOME") .. "/.local/bin/webapp-focus https://linear.app")
app("A", "ChatGPT", "chrome-chatgpt.com__-Default", os.getenv("HOME") .. "/.local/bin/webapp-focus https://chatgpt.com/")
app("D", "Discord", "discord", focus("discord discord"))
app("S", "Signal and Telegram", "signal", focus("'^(signal|org\\.telegram\\.desktop)$' signal-desktop"))
app("C", "Chatterino", "com.chatterino.chatterino", focus("chatterino chatterino"))
app("O", "OBS", "com.obsproject.Studio", focus("obsproject obs"))
app("SLASH", "Bitwarden", "Bitwarden", focus("'^bitwarden$' bitwarden-desktop"))
note("Apps", HYPER .. " + app key, again", "Next window of the same app")
note("Apps", HYPER .. " + SHIFT + app key", "Send window to that app's workspace")

hyper("Windows", "W", "Close window", hl.dsp.window.close())
bind("Windows", "SUPER + Q", "Quit app (all its windows)", scripts .. "/quit-app")
hyper("Windows", "M", "Maximize (keeps bar and gaps)", hl.dsp.window.fullscreen({ mode = "maximized" }))
hyper("Windows", "Return", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- Super + F and Super + Alt + F only toggle their own mode; this leaves either.
hyper("Windows", "F", "Back to normal size", hl.dsp.window.fullscreen_state({ internal = 0, client = 0 }))
hyper("Windows", "J", "Float or tile window", hl.dsp.window.float({ action = "toggle" }))
-- Only floating windows can be pinned; the tag sends a window floated here back to tiling on unpin.
hyper("Windows", "P", "Keep window on top (pin)", function()
  local w = hl.get_active_window()
  if not w then return end
  if w.pinned then
    hl.dispatch(hl.dsp.window.pin({ window = w }))
    local tags = w.tags
    if type(tags) ~= "table" then tags = {} end
    for _, tag in ipairs(tags) do
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
hyper("Windows", "SHIFT + P", "Pop window out (float and pin)", "omarchy-hyprland-window-pop")
-- keyd sends Cmd + H / Cmd + M here (see omarchy/keyd/common); hidden windows come back from the bar, the menu or Hyper + Shift + H.
bind("Windows", "SUPER + SHIFT + H", "Hide window", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
-- Arrows position the window (portrait: halves and thirds, top screen: column); Shift sends it to the screen that way.
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  hyper(nil, dir:upper(), "Move window " .. dir, M.arrow(dir))
  hyper(nil, "SHIFT + " .. dir:upper(), "Send window to the screen " .. dir, M.send(dir))
end
note("Windows", HYPER .. " + ARROWS", "Move window within its screen (halves, thirds, columns)")
hyper("Windows", "SHIFT + L", "Put every window back in its place", W.place_all)
-- keyd leaves no key sending plain Super, so Omarchy's Super+drag is unreachable; Wine title bars cannot be dragged at all.
bind("Windows", HYPER .. " + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
bind("Windows", HYPER .. " + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Ctrl stays Ctrl for apps, so window management lives on Hyper as with skhd on the Mac; digits use keycodes so Shift does not turn them into symbols.
-- 7 and 9 are the sound and gaming workspaces, reached by U and G instead.
for workspace = 1, 10 do
  if workspace ~= 7 and workspace ~= 9 then
    local key = "code:" .. tostring(workspace + 9)
    hyper(nil, key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
    hyper(nil, "SHIFT + " .. key, "Send window to workspace " .. workspace, M.send_to(tostring(workspace)))
  end
end
note("Workspaces", HYPER .. " + 1…6, 8, 0", "Go to workspace 1–6, 8, 10")
note("Workspaces", HYPER .. " + SHIFT + 1…6, 8, 0", "Send window to workspace 1–6, 8, 10")
hyper("Workspaces", "G", "Go to the gaming workspace (9)", hl.dsp.focus({ workspace = C.gaming_workspace }))
hyper("Workspaces", "SHIFT + G", "Send window to the gaming workspace", M.send_to(C.gaming_workspace))
hyper("Workspaces", "U", "Go to the sound workspace (7)", hl.dsp.focus({ workspace = C.homes.opendeck }))
hyper("Workspaces", "SHIFT + U", "Send window to the sound workspace", M.send_to(C.homes.opendeck))

note("Screens", HYPER .. " + SHIFT + ARROWS", "Send window to the screen in that direction")

-- Mac screenshot keys: keyd sends Cmd + Shift + 3/4 as these (code:12/13 are 3/4).
bind("Capture", "SUPER + SHIFT + code:12", "Screenshot whole screen to clipboard", "omarchy-capture-screenshot fullscreen copy")
bind("Capture", "SUPER + SHIFT + code:13", "Screenshot region or window to clipboard", "omarchy-capture-screenshot smart copy")
bind("Capture", "SUPER + CTRL + SHIFT + code:12", "Screenshot whole screen to file and clipboard", "omarchy-capture-screenshot fullscreen")
bind("Capture", "SUPER + CTRL + SHIFT + code:13", "Screenshot region or window to file and clipboard", "omarchy-capture-screenshot smart")

bind("System", "SUPER + SPACE", "Omarchy menu", M.menu)
hyper("System", "H", "Keybindings (this list)", scripts .. "/keybindings")
-- The Keychron sends Ctrl + Super + Q for Fn + L, the Mac lock key.
bind("System", "SUPER + CTRL + Q", "Lock and turn off screens (Fn + L)", "omarchy-system-lock && sleep 1 && omarchy-brightness-display off")

-- Omarchy's defaults sit on plain Super, which keyd leaves no key for (hyprland.lua turns them off);
-- these are loaded from its files onto keys that exist: { section, new keys or same, better description }.
local from_omarchy = {
  ["SUPER + code:20"] = { "Windows", HYPER .. " + code:20", "Make window narrower" },
  ["SUPER + code:21"] = { "Windows", HYPER .. " + code:21", "Make window wider" },
  ["SUPER + SHIFT + code:20"] = { "Windows", HYPER .. " + SHIFT + code:20", "Make window shorter" },
  ["SUPER + SHIFT + code:21"] = { "Windows", HYPER .. " + SHIFT + code:21", "Make window taller" },
  ["SUPER + S"] = { "Windows", HYPER .. " + SHIFT + H", "Show or hide hidden windows (scratchpad)" },
  ["SUPER + CTRL + TAB"] = { "Workspaces", HYPER .. " + TAB", "Back to the previous workspace" },
  ["CTRL + ALT + TAB"] = { "Screens", nil, "Focus next screen" },
  ["CTRL + ALT + SHIFT + TAB"] = { "Screens", nil, "Focus previous screen" },
  ["SUPER + SHIFT + F"] = { "Apps", HYPER .. " + R", "Files (Nautilus)" },
  ["PRINT"] = { "Capture", nil, "Screenshot (pick region, window or screen)" },
  ["ALT + PRINT"] = { "Capture", nil, "Start or stop screen recording" },
  -- keyd sends Cmd + Shift + 5 here, the macOS capture menu key.
  ["SUPER + CTRL + C"] = { "Capture", "SUPER + SHIFT + code:14", "Capture menu (screenshot, recording, color picker, OCR)" },
  ["SUPER + comma"] = { "Notifications", HYPER .. " + comma", "Dismiss the latest notification" },
  ["SUPER + SHIFT + comma"] = { "Notifications", HYPER .. " + SHIFT + comma", "Dismiss all notifications" },
  ["SUPER + SHIFT + ALT + comma"] = { "Notifications", HYPER .. " + period", "Notification history" },
  ["SUPER + CTRL + comma"] = { "Notifications", HYPER .. " + SHIFT + period", "Do not disturb on/off" },
  ["SUPER + ESCAPE"] = { "System", HYPER .. " + ESCAPE", "System menu (lock, suspend, restart, shut down)" },
  ["SUPER + CTRL + O"] = { "System", HYPER .. " + X", "Toggle menu (nightlight, idle lock, bar, gaps)" },
  ["SUPER + CTRL + V"] = { "System", nil, "Clipboard history" },
  ["SUPER + CTRL + E"] = { "System", nil, "Emoji picker" },
  ["XF86Calculator"] = { "System", nil, "Calculator" },
  ["XF86PowerOff"] = { "System", nil, "System menu" },
}

---@diagnostic disable-next-line: duplicate-set-field
o.bind = function(keys, description, dispatcher, opts)
  local import = from_omarchy[keys]
  if import then bind(import[1], import[2] or keys, import[3] or description, dispatcher, opts) end
end
-- utilities also adds the region picker's own keys while a selection is on screen.
for _, file in ipairs({ "clipboard", "tiling", "utilities", "applications" }) do
  require("default.hypr.bindings." .. file)
end
o.bind = omarchy_bind

-- Cmd + Tab arrives as Super + Tab (keyd's cmdtab layer); the submap keeps Super + Esc from opening the system menu.
local switching = false

local function switcher(action, leave)
  return function()
    if action == "commit" and not switching then return end
    switching = not leave
    hl.exec_cmd("omarchy-shell -q alttab " .. action)
    hl.dispatch(hl.dsp.submap(leave and "reset" or "alttab"))
  end
end

bind(nil, "SUPER + TAB", "Switch windows", switcher("next"))
bind(nil, "SUPER + SHIFT + TAB", "Switch windows backwards", switcher("prev"))
-- A quick tap can release Cmd before the submap is entered, so the release also commits outside it, but only mid-switch.
bind(nil, "SUPER + SUPER_L", "Finish window switch", switcher("commit", true), { release = true, transparent = true })
note("Windows", "SUPER + TAB", "Switch windows (Cmd + Tab; Shift: backwards, Esc: cancel)")

hl.define_submap("alttab", function()
  omarchy_bind("SUPER + TAB", "Next window", switcher("next"))
  omarchy_bind("SUPER + SHIFT + TAB", "Previous window", switcher("prev"))
  omarchy_bind("SUPER + ESCAPE", "Cancel window switch", switcher("cancel", true))
  -- The release bind also covers a tap that ends before the overlay grabs the keyboard.
  omarchy_bind("SUPER + SUPER_L", "Finish window switch", switcher("commit", true), { release = true, transparent = true })
  -- Adding Shift mid-switch steps backwards on the next Tab, so the Shift press itself must not reach the catchall.
  for _, shift in ipairs({ "Shift_L", "Shift_R" }) do
    omarchy_bind("SUPER + " .. shift, "Hold Shift in window switch", function() end)
    omarchy_bind("SUPER + SHIFT + " .. shift, "Hold Shift in window switch", function() end)
  end
  -- Any other key leaves the switcher, so a missed release can never strand the keyboard in this submap.
  omarchy_bind("catchall", "Leave window switch", switcher("cancel", true))
end)
