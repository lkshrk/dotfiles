-- Output name of the portrait monitor (see `hyprctl monitors`); nil opens workspace 6 on the focused monitor.
local portrait_monitor = nil
local bar_height = 43

-- One workspace per main app, tiled: alone on its workspace each fills the screen, and nothing overlaps.
-- Workspace 1 collects every app without its own rule; the rules below override it.
o.window(".*", { workspace = "1" })
o.window("(?i)^(foot|footclient|Alacritty|com\\.mitchellh\\.ghostty)$", { workspace = "2" })
o.window("^helium$", { workspace = "3" })
o.window("^dev\\.zed\\.Zed(-Preview|-Nightly)?$", { workspace = "4" })
-- PipeWeaver's Chromium web app; Chromium drops the port from the class.
o.window("^chrome-localhost__-Default$", { workspace = "7" })

if portrait_monitor then
  hl.workspace_rule({ workspace = "6", monitor = portrait_monitor, default = true })
end

-- Messengers float on workspace 6 so the portrait layout can overlap them.
o.window("(?i)^(discord|signal|org\\.telegram\\.desktop|com\\.obsproject\\.studio|obsidian|brave-browser)$", {
  workspace = "6",
  float = true,
})

-- Opened from the Stats bar widget for a quick look, like Activity Monitor.
o.window("^io\\.missioncenter\\.MissionCenter$", {
  workspace = "unset",
  float = true,
  center = true,
  size = { "(monitor_w*0.6)", "(monitor_h*0.7)" },
})

-- Password managers block screen capture, so they get a workspace to themselves.
o.window("^(Bitwarden|1[pP]assword)$", { workspace = "8" })

o.window("(?i)chatterino", {
  workspace = "6",
  float = true,
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
o.window({ tag = "dialog" }, { float = true, center = true })
-- Dialogs, PiP and Omarchy's floating tools open where they were triggered, not in the collector.
o.window({ tag = "dialog" }, { workspace = "unset" })
o.window({ tag = "pip" }, { workspace = "unset" })
o.window({ tag = "floating-window" }, { workspace = "unset" })
