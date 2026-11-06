local C = require("hypr.screens.config")

-- One tiled workspace per main app; screens/windows.lua collects tiled apps without a home onto workspace 1.
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

o.window("^org\\.gnome\\.Nautilus$", {
  workspace = "unset",
  float = true,
  center = true,
  size = { "(monitor_w*0.5)", "(monitor_h*0.6)" },
})

o.window("^org\\.omarchy\\.markdown$", {
  float = true,
  center = true,
  size = { "(monitor_w*0.4)", "(monitor_h*0.75)" },
})

-- Launchers float (screens/frames.lua restores their frame) and never take focus on their own, which would raise them over the fullscreen game.
o.window("^wowupcf$", { float = true, suppress_event = "maximize activatefocus" })
o.window({ class = "^(steam_app_battlenet|battle\\.net\\.exe)$", title = "^Battle\\.net$" }, { float = true, suppress_event = "maximize activatefocus" })
-- Games run borderless at monitor size without requesting fullscreen, which leaves the bar above them.
o.window("^(steam_app_[0-9]+|gamescope|wow\\.exe)$", { fullscreen = true, idle_inhibit = "fullscreen" })
-- Battle.net games share the launcher's class, so only known game titles go fullscreen; launcher dialogs stay windowed.
o.window({
  class = "^(steam_app_battlenet|battle\\.net\\.exe)$",
  title = "^(World of Warcraft|Diablo IV|Diablo II: Resurrected|Warcraft III|Hearthstone|Overwatch|StarCraft.*)$",
}, { fullscreen = true, idle_inhibit = "fullscreen" })

o.window({ modal = true }, { tag = "+dialog" })
o.window("^(xdg-desktop-portal-gtk|zenity)$", { tag = "+dialog" })
-- pinentry-gnome3 prompts through gcr-prompter; neither is modal to any window, so pin them to stay on the visible workspace.
o.window("^(gcr-prompter|[Pp]inentry.*)$", { tag = "+dialog", pin = true })
o.window({ tag = "dialog" }, { float = true, center = true })
-- Dialogs, PiP and Omarchy's floating tools open where they were triggered, not in the collector.
o.window({ tag = "dialog" }, { workspace = "unset" })
o.window({ tag = "pip" }, { workspace = "unset" })
o.window({ tag = "floating-window" }, { workspace = "unset" })
o.window("^(org\\.omarchy\\..*|omacalc|dev\\.tensaku\\.Tensaku|WebcamOverlay-.*|(org\\.localsend\\.)?localsend(_app)?|Share|Hermes)$", { workspace = "unset" })
o.window("^org\\.omarchy\\.screensaver$", { workspace = "special:screensaver silent" })
-- Re-applied because the per-app workspace rules above override Omarchy's for browser windows.
o.window({ title = ".*is sharing.*" }, { workspace = "special silent" })
-- A web app's own browser window only exists until webapp-links hands its tab to the default browser.
o.window("^webapp-.*$", { workspace = "special:webapp-links silent" })
-- Password managers block screen capture, so they get a tiled workspace to themselves; tag rules apply last, so drop Omarchy's floating-window tag.
o.window("^(Bitwarden|1[pP]assword|com\\.onepassword\\.OnePassword)$", { tag = "-floating-window", tile = true, workspace = C.homes.Bitwarden })
-- The Bitwarden extension popout opens where it was triggered; screens/util.lua leaves it alone like a dialog.
o.window(".*nngceckbapebfimnlniiiahkandclblb.*", { tag = "+bitwarden-popup", workspace = "unset" })

-- Every window slightly translucent, browsers only when unfocused, and media, games and overlays opaque.
o.transparent_window(".*")
o.window({ tag = "chromium-based-browser" }, { opacity = "1.0 0.985" })
o.window({ tag = "firefox-based-browser" }, { opacity = "1.0 0.985" })
for _, match in ipairs({
  "(.*[Rr]esolve.*|qemu|com\\.libretro\\.RetroArch|steam.*|zoom|vlc|mpv|org\\.kde\\.kdenlive|com\\.obsproject\\.Studio|com\\.github\\.PintaProject\\.Pinta|imv|org\\.gnome\\.NautilusPreviewer|.+-youtube\\.com__.*|.+-app\\.zoom\\.us__wc_home.*)",
  { tag = "pip" },
  { tag = "chromium-based-browser", title = "^Meet - .+" },
  { class = "^Hermes$", title = "^Hermes HUD$" },
  { class = "^WebcamOverlay-(small|medium|large)$", title = "^WebcamOverlay$" },
}) do
  o.window(match, { opacity = "1 1" })
end

-- The screenshot freeze would otherwise animate in and out over the live screen, showing as a flash.
hl.layer_rule({ match = { namespace = "hyprpicker" }, no_anim = true })
