-- One tiled workspace per main app; workspace 1 collects every app without its own rule.
o.window(".*", { workspace = "1" })
o.window("(?i)^(foot|footclient|Alacritty|com\\.mitchellh\\.ghostty)$", { workspace = "2" })
o.window("^helium$", { workspace = "3" })
o.window("^dev\\.zed\\.Zed(-Preview|-Nightly)?$", { workspace = "4" })
o.window("^chrome-linear\\.app__-Default$", { workspace = "5" })

-- Portrait-screen apps float into their thirds slot (see screens.lua).
o.window("(?i)^(discord|signal|org\\.telegram\\.desktop|com\\.obsproject\\.studio|com\\.chatterino\\.chatterino|chatgpt)$", {
  workspace = "6",
  float = true,
})
o.window("^(chrome-localhost__-Default|opendeck)$", { workspace = "7", float = true })
o.window("^(brave-browser|md\\.obsidian\\.Obsidian)$", { workspace = "10" })

-- Opened from the Stats bar widget for a quick look, like Activity Monitor.
o.window("^io\\.missioncenter\\.MissionCenter$", {
  workspace = "unset",
  float = true,
  center = true,
  size = { "(monitor_w*0.6)", "(monitor_h*0.7)" },
})

o.window("^(steam|steam_app_[0-9]+|steam_app_battlenet|gamescope|com\\.moonlight_stream\\.Moonlight|wowupcf)$", { workspace = "9" })
-- Launchers float and reopen at the size they were last left at; games sharing Battle.net's class match their own titles below.
o.window("^wowupcf$", { float = true, persistent_size = true })
o.window({ class = "^steam_app_battlenet$", title = "^Battle\\.net$" }, { float = true, persistent_size = true })
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
-- Password managers block screen capture, so they get a tiled workspace to themselves; tag rules apply last, so drop Omarchy's floating-window tag.
o.window("^(Bitwarden|1[pP]assword)$", { tag = "-floating-window", tile = true, workspace = "8" })
-- Omarchy only catches Chrome's class for the Bitwarden extension popup; Brave prefixes it "brave-".
o.window("^.+-nngceckbapebfimnlniiiahkandclblb-Default$", { no_screen_share = true, tag = "+floating-window" })
