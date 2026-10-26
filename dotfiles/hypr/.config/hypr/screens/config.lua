-- Which monitor owns which workspace, and where apps live; data only.
local C = {}

C.main = "desc:Samsung Electric Company Odyssey G80SH HNBL500080"
C.top = "desc:Samsung Electric Company Odyssey G60SD HNAX800191"
C.side = "desc:Samsung Electric Company Odyssey G60SD HNAX800182"

C.top_workspace = "10"
C.gaming_workspace = "9"
C.side_workspaces = { ["6"] = true, ["7"] = true }

for _, workspace in ipairs({ "1", "2", "3", "4", "5", "8", "9" }) do
  hl.workspace_rule({ workspace = workspace, monitor = C.main, default = workspace == "1" })
end
hl.workspace_rule({ workspace = "10", monitor = C.top, default = true, persistent = true, layout = "lua:columns" })
hl.workspace_rule({ workspace = "6", monitor = C.side, default = true, persistent = true })
hl.workspace_rule({ workspace = "7", monitor = C.side, persistent = true })

local TOP, MID, BOT = 0, 1, 2
C.MID = MID

-- Each app's workspace, portrait-screen slot (col/cols default to full width), and multi = several equal windows on purpose.
local apps = {
  { "foot", "footclient", "Alacritty", "com.mitchellh.ghostty", workspace = "2", multi = true },
  { "helium", workspace = "3", slot = { row = MID }, multi = true },
  { "dev.zed.Zed", "dev.zed.Zed-Preview", "dev.zed.Zed-Nightly", workspace = "4", multi = true },
  { "chrome-linear.app__-Default", workspace = "5" },
  { "discord", workspace = "6", slot = { row = TOP } },
  { "chatgpt", workspace = "6", slot = { row = MID } },
  { "signal", "org.telegram.desktop", workspace = "6", slot = { row = BOT } },
  { "com.chatterino.chatterino", workspace = "6", slot = { row = BOT, col = 2, cols = 1, above = true } },
  { "chrome-localhost__-Default", workspace = "7", slot = { row = TOP } },
  { "com.obsproject.Studio", workspace = "7", slot = { row = MID } },
  { "opendeck", workspace = "7", slot = { row = BOT } },
  { "Bitwarden", "1password", "1Password", workspace = "8" },
  { "steam", "gamescope", "com.moonlight_stream.Moonlight", "wowupcf", workspace = "9" },
  { "steam_app_battlenet", workspace = "9", multi = true },
  { "brave-browser", "md.obsidian.Obsidian", workspace = "10" },
}

C.apps = apps
C.homes, C.slots, C.multi_window = {}, {}, {}
for _, app in ipairs(apps) do
  for _, class in ipairs(app) do
    C.homes[class] = app.workspace
    C.slots[class] = app.slot
    C.multi_window[class] = app.multi
  end
end

-- Workspaces whose windows stay floating when put back in place.
C.floating_workspaces = { ["6"] = true, ["7"] = true, ["9"] = true }

-- A window open this long is no splash; a newer window of a single-window app then counts as an extra.
C.settle_ms = 1500
-- Only a window open this long may set its app's frame, so a login box cannot become it.
C.remember_after_ms = 10000
C.frame_snapshot_ms = 5000
-- X11 launchers place themselves just after mapping, so remembered frames wait this long.
C.frame_open_delay_ms = 500
C.frame_max_age_days = 60

-- Helium windows look identical; the one named this (Name window…) lives on main, the rest on the portrait screen.
C.helium_main_title = "Main"
C.helium_main_workspace = "3"

-- Passphrase prompts (SSH keys, keyrings) are app-independent, so they always ask on the main monitor.
C.password_prompt = { ["gcr-prompter"] = true, pinentry = true, ["pinentry-gtk"] = true, ["pinentry-qt"] = true, ["Pinentry-gtk"] = true }

return C
