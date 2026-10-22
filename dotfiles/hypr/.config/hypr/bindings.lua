-- Personal keybindings, loaded after Omarchy's defaults. Omarchy's SUPER layer
-- stays as shipped; Hyper only adds what it has no equivalent for (skhdrc).
--
-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Window and workspace rules (the yabai placement port).
require("hypr.rules")

-- Hyper is Caps Lock: keyd maps it to SUPER + CTRL + ALT, like Cmd + Ctrl + Opt
-- on the Mac (see omarchy/keyd/default.conf in the dotfiles repo).
local HYPER = "SUPER + CTRL + ALT"
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

local function hyper(keys, description, dispatcher)
  o.bind(HYPER .. " + " .. keys, description, dispatcher)
end

local function focus(args)
  return scripts .. "/focus-app " .. args
end

-- Omarchy puts notifications on three Hyper keys; they stay available from the bar.
hl.unbind(HYPER .. " + B") -- was: Show battery remaining
hl.unbind(HYPER .. " + D") -- was: Calendar
hl.unbind(HYPER .. " + T") -- was: Show time

-- Apps: focus the most recent window, cycle on repeat, launch if none is open.
hyper("B", "Helium", focus("'^helium$' omarchy-launch-browser"))
hyper("C", "Chatterino", focus("chatterino chatterino"))
hyper("D", "Discord", focus("discord discord"))
hyper("E", "Next editor", focus("--order stable --title '\\.nvim\\.' zed zeditor"))
hyper("SHIFT + E", "Previous editor", focus("--order stable --reverse --title '\\.nvim\\.' zed zeditor"))
hyper("G", "Gaming workspace", hl.dsp.focus({ workspace = "9" }))
hyper("K", "Linear", focus("'^chrome-linear\\.app__-Default$' chromium --app=https://linear.app"))
hyper("N", "Obsidian", focus("'^obsidian$' obsidian"))
hyper("O", "OBS", focus("obsproject obs"))
hyper("V", "Brave", focus("'^brave-browser$' brave"))
hyper("S", "Messengers", focus("'^(signal|org\\.telegram\\.desktop)$' signal-desktop"))
hyper("T", "Terminal", focus("--exclude-title '\\.nvim\\.' '^(foot|footclient|Alacritty)$' xdg-terminal-exec"))
hyper("A", "ChatGPT", focus("'^chrome-chatgpt\\.com__-Default$' chromium --app=https://chatgpt.com"))
hyper("SLASH", "Bitwarden", focus("'^bitwarden$' bitwarden-desktop"))

-- Window placement.
hyper("LEFT", "Move window left", hl.dsp.window.move({ direction = "left" }))
hyper("RIGHT", "Move window right", hl.dsp.window.move({ direction = "right" }))
hyper("UP", "Move window up", hl.dsp.window.move({ direction = "up" }))
hyper("DOWN", "Move window down", hl.dsp.window.move({ direction = "down" }))
-- Back to the window's normal size from full screen or full width, whichever
-- it is in: Super + F and Super + Alt + F only toggle their own mode, and games
-- start full screen through a window rule.
hyper("F", "Normal size", hl.dsp.window.fullscreen_state({ internal = 0, client = 0 }))

-- Mac screenshot keys (code:12/13 are 3/4); moving a window to workspace 3/4 stays on Super + Shift + Alt.
hl.unbind("SUPER + SHIFT + code:12") -- was: Move window to workspace 3
hl.unbind("SUPER + SHIFT + code:13") -- was: Move window to workspace 4
o.bind("SUPER + SHIFT + code:12", "Screenshot full screen to clipboard", scripts .. "/screenshot-copy fullscreen")
o.bind("SUPER + SHIFT + code:13", "Screenshot region or window to clipboard", scripts .. "/screenshot-copy smart")
o.bind("SUPER + CTRL + SHIFT + code:12", "Screenshot full screen to file and clipboard", "omarchy-capture-screenshot fullscreen")
o.bind("SUPER + CTRL + SHIFT + code:13", "Screenshot region or window to file and clipboard", "omarchy-capture-screenshot smart")

-- The Keychron sends Ctrl + Super + Q for Fn + L (the Mac lock key): lock and turn the monitors off,
-- without suspending; any key or mouse movement wakes them.
hl.unbind("SUPER + CTRL + Q") -- was: Calculator
o.bind("SUPER + CTRL + Q", "Lock and turn off monitors", "omarchy-system-lock && sleep 1 && omarchy-brightness-display off")

-- Super + Q quits the focused app (all its windows), like Cmd + Q; Super + W
-- still closes just the one window.
o.bind("SUPER + Q", "Quit application", scripts .. "/quit-app")

-- Alt-Tab with live previews, most recently focused first (the lkshrk.alttab
-- shell plugin). Releasing Alt switches; the release bind covers a quick tap
-- that finishes before the overlay grabs the keyboard.
hl.unbind("ALT + TAB") -- was: Focus on next window / Reveal active window on top
hl.unbind("ALT + SHIFT + TAB") -- was: Focus on previous window / Reveal active window on top
o.bind("ALT + TAB", "Switch windows", "omarchy-shell -q alttab next")
o.bind("ALT + SHIFT + TAB", "Switch windows backwards", "omarchy-shell -q alttab prev")
o.bind("ALT + ALT_L", "Finish window switch", "omarchy-shell -q alttab commit", { release = true, transparent = true })

-- Same switcher on Super + Tab, like Cmd + Tab on the Mac. Omarchy's next and
-- previous workspace move off it; Super + Ctrl + Tab still returns to the former one.
hl.unbind("SUPER + TAB") -- was: Next workspace
hl.unbind("SUPER + SHIFT + TAB") -- was: Previous workspace
o.bind("SUPER + TAB", "Switch windows", "omarchy-shell -q alttab next")
o.bind("SUPER + SHIFT + TAB", "Switch windows backwards", "omarchy-shell -q alttab prev")
o.bind("SUPER + SUPER_L", "Finish window switch", "omarchy-shell -q alttab commit", { release = true, transparent = true })
