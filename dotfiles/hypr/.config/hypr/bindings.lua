require("hypr.rules")

-- keyd turns Caps Lock into this chord.
local HYPER = "SUPER + CTRL + ALT"
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

local function hyper(keys, description, dispatcher)
  o.bind(HYPER .. " + " .. keys, description, dispatcher)
end

local function focus(args)
  return scripts .. "/focus-app " .. args
end

-- Omarchy puts notifications on three Hyper keys; they stay available from the bar.
hl.unbind(HYPER .. " + B")
hl.unbind(HYPER .. " + D")
hl.unbind(HYPER .. " + T")

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

hyper("LEFT", "Move window left", hl.dsp.window.move({ direction = "left" }))
hyper("RIGHT", "Move window right", hl.dsp.window.move({ direction = "right" }))
hyper("UP", "Move window up", hl.dsp.window.move({ direction = "up" }))
hyper("DOWN", "Move window down", hl.dsp.window.move({ direction = "down" }))
-- Super + F and Super + Alt + F only toggle their own mode; this leaves either.
hyper("F", "Normal size", hl.dsp.window.fullscreen_state({ internal = 0, client = 0 }))

-- Mac screenshot keys (code:12/13 are 3/4); moving a window to workspace 3/4 stays on Super + Shift + Alt.
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

-- The release bind covers a tap that ends before the overlay grabs the keyboard.
hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
o.bind("ALT + TAB", "Switch windows", "omarchy-shell -q alttab next")
o.bind("ALT + SHIFT + TAB", "Switch windows backwards", "omarchy-shell -q alttab prev")
o.bind("ALT + ALT_L", "Finish window switch", "omarchy-shell -q alttab commit", { release = true, transparent = true })

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + TAB", "Switch windows", "omarchy-shell -q alttab next")
o.bind("SUPER + SHIFT + TAB", "Switch windows backwards", "omarchy-shell -q alttab prev")
o.bind("SUPER + SUPER_L", "Finish window switch", "omarchy-shell -q alttab commit", { release = true, transparent = true })
