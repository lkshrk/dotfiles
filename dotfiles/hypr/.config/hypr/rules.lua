-- Output name of the portrait monitor (see `hyprctl monitors`); nil opens workspace 6 on the focused monitor.
local portrait_monitor = nil
local bar_height = 43

hl.workspace_rule({ workspace = "1", layout = "monocle" })

-- First, so app-specific rules and Omarchy's tagged floats can still place and size windows.
o.window(".*", { float = true, center = true })
-- Omarchy's browser.lua tiles this tag, which beats the catch-all float above.
o.window({ tag = "chromium-based-browser" }, { float = true })

-- Screen-sized floats, not maximize: a workspace holds only one maximized window, which stays above focused floats.
local top_bar = 26
local screen_sized = {
  size = { "(monitor_w)", "(monitor_h-" .. top_bar .. ")" },
  move = { "(0)", "(" .. top_bar .. ")" },
}
o.window("(?i)^(foot|footclient|Alacritty|com\\.mitchellh\\.ghostty|dev\\.zed\\.Zed(-Preview|-Nightly)?|helium)$", screen_sized)
-- PipeWeaver's Chromium web app; Chromium drops the port from the class.
o.window("^chrome-localhost__-Default$", screen_sized)

if portrait_monitor then
  hl.workspace_rule({ workspace = "6", monitor = portrait_monitor, default = true })
end

o.window("(?i)^(discord|signal|org\\.telegram\\.desktop|com\\.obsproject\\.studio|obsidian|brave-browser)$", { workspace = "6" })

-- Password managers block screen capture, so they get a workspace to themselves.
o.window("^(Bitwarden|1[pP]assword)$", { workspace = "8" })

o.window("(?i)chatterino", {
  workspace = "6",
  size = { "(monitor_w*0.33)", "(monitor_h*0.25)" },
  move = { "(monitor_w-window_w)", "(monitor_h-window_h-" .. bar_height .. ")" },
})

o.window("^(steam_app_[0-9]+|steam_app_battlenet|gamescope|com\\.moonlight_stream\\.Moonlight)$", { workspace = "9" })
-- Games run borderless at monitor size without requesting fullscreen, which leaves the bar above them.
o.window("^(steam_app_[0-9]+|gamescope)$", { fullscreen = true, idle_inhibit = "fullscreen" })
-- Battle.net games share the launcher's class, so only known game titles go fullscreen; launcher dialogs stay windowed.
o.window({
  class = "^steam_app_battlenet$",
  title = "^(World of Warcraft|Diablo IV|Diablo II: Resurrected|Warcraft III|Hearthstone|Overwatch|StarCraft.*)$",
}, { fullscreen = true, idle_inhibit = "fullscreen" })

o.window({ modal = true }, { tag = "+dialog" })
o.window("^(xdg-desktop-portal-gtk|zenity)$", { tag = "+dialog" })
-- pinentry-gnome3 prompts through gcr-prompter; neither is modal to any window.
o.window("^(gcr-prompter|[Pp]inentry.*)$", { tag = "+dialog" })
o.window({
  class = "(sublime_text|DesktopEditors|org.gnome.Nautilus)",
  title = "^(Open.*Files?|Open [Ff]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to (open|save).*|[Cc]hoose.*)",
}, { tag = "+dialog" })
o.window({ tag = "dialog" }, { float = true, center = true, maximize = false })
o.window({ tag = "pip" }, { maximize = false })
