local C = require("hypr.screens.config")

-- One tiled workspace per main app; workspace 1 collects every app without its own rule.
o.window(".*", { workspace = "1" })
for _, app in ipairs(C.apps) do
  local classes = {}
  for i, class in ipairs(app) do classes[i] = class:gsub("%.", "\\.") end
  -- Portrait-screen apps float into their thirds slot (see screens/side.lua).
  o.window("(?i)^(" .. table.concat(classes, "|") .. ")$", { workspace = app.workspace, float = C.side_workspaces[app.workspace] })
end
-- Steam games, and Chatterino's X11 class (U.app maps both to their app).
o.window("^steam_app_[0-9]+$", { workspace = C.gaming_workspace })
o.window("^chatterino$", { workspace = "6", float = true })

-- Opened from the Stats bar widget for a quick look, like Activity Monitor.
o.window("^io\\.missioncenter\\.MissionCenter$", {
  workspace = "unset",
  float = true,
  center = true,
  size = { "(monitor_w*0.6)", "(monitor_h*0.7)" },
})

-- Launchers float (screens/frames.lua restores their frame); games sharing Battle.net's class match their own titles below.
o.window("^wowupcf$", { float = true })
o.window({ class = "^steam_app_battlenet$", title = "^Battle\\.net$" }, { float = true })
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
-- A web app's own browser window only exists until webapp-links hands its tab to the default browser.
o.window("^webapp-.*$", { workspace = "special:webapp-links silent" })
-- Password managers block screen capture, so they get a tiled workspace to themselves; tag rules apply last, so drop Omarchy's floating-window tag.
o.window("^(Bitwarden|1[pP]assword)$", { tag = "-floating-window", tile = true, workspace = C.homes.Bitwarden })
-- Omarchy only catches Chrome's class for the Bitwarden extension popup; Brave prefixes it "brave-".
o.window("^.+-nngceckbapebfimnlniiiahkandclblb-Default$", { no_screen_share = true, tag = "+floating-window" })
