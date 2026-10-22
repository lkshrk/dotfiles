local bar_height = 43

-- One workspace per main app, tiled: alone on its workspace each fills the screen, and nothing overlaps.
-- Workspace 1 collects every app without its own rule; the rules below override it.
o.window(".*", { workspace = "1" })
o.window("(?i)^(foot|footclient|Alacritty|com\\.mitchellh\\.ghostty)$", { workspace = "2" })
o.window("^helium$", { workspace = "3" })
o.window("^dev\\.zed\\.Zed(-Preview|-Nightly)?$", { workspace = "4" })
o.window("^chrome-linear\\.app__-Default$", { workspace = "5" })
-- PipeWeaver's Chromium web app; Chromium drops the port from the class.
o.window("^chrome-localhost__-Default$", { workspace = "7" })

-- Messengers, OBS, Obsidian and Brave float together on workspace 6.
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

o.window("(?i)chatterino", {
  workspace = "6",
  float = true,
  size = { "(monitor_w*0.33)", "(monitor_h*0.25)" },
  move = { "(monitor_w-window_w)", "(monitor_h-window_h-" .. bar_height .. ")" },
})

o.window("^(steam|steam_app_[0-9]+|steam_app_battlenet|gamescope|com\\.moonlight_stream\\.Moonlight|wowupcf)$", { workspace = "9" })
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
o.window({ tag = "dialog" }, { float = true, center = true })
-- Dialogs, PiP and Omarchy's floating tools open where they were triggered, not in the collector.
o.window({ tag = "dialog" }, { workspace = "unset" })
o.window({ tag = "pip" }, { workspace = "unset" })
o.window({ tag = "floating-window" }, { workspace = "unset" })
o.window("^(org\\.omarchy\\..*|omacalc|dev\\.tensaku\\.Tensaku|WebcamOverlay-.*|localsend|Share|Hermes)$", { workspace = "unset" })
-- Re-applied because the collector rule above overrides Omarchy's earlier one.
o.window({ title = ".*is sharing.*" }, { workspace = "special silent" })
-- Password managers block screen capture, so they get a workspace to themselves; after the floating-window unset.
o.window("^(Bitwarden|1[pP]assword)$", { workspace = "8" })
