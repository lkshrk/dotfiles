-- Which monitor owns which workspace, and where apps live; data only.
local C = {}

C.main = "desc:Samsung Electric Company Odyssey G80SH HNBL500080"
C.top = "desc:Samsung Electric Company Odyssey G60SD HNAX800191"
C.side = "desc:Samsung Electric Company Odyssey G60SD HNAX800182"

C.top_workspace = "10"
C.side_workspaces = { ["6"] = true, ["7"] = true }

for _, workspace in ipairs({ "1", "2", "3", "4", "5", "8", "9" }) do
  hl.workspace_rule({ workspace = workspace, monitor = C.main, default = workspace == "1" })
end
hl.workspace_rule({ workspace = "10", monitor = C.top, default = true, persistent = true, layout = "lua:columns" })
hl.workspace_rule({ workspace = "6", monitor = C.side, default = true, persistent = true })
hl.workspace_rule({ workspace = "7", monitor = C.side, persistent = true })

local TOP, MID, BOT = 0, 1, 2
C.MID = MID

-- Portrait screen slots in thirds; col/cols default to the full width.
C.slots = {
  discord = { row = TOP },
  helium = { row = MID },
  chatgpt = { row = MID },
  signal = { row = BOT },
  ["org.telegram.desktop"] = { row = BOT },
  ["com.obsproject.studio"] = { row = BOT },
  ["com.chatterino.chatterino"] = { row = BOT, col = 2, cols = 1, above = true },
  ["chrome-localhost__-Default"] = { row = TOP },
  opendeck = { row = BOT },
}

C.homes = {
  foot = "2", footclient = "2", Alacritty = "2", ["com.mitchellh.ghostty"] = "2",
  helium = "3",
  ["dev.zed.Zed"] = "4", ["dev.zed.Zed-Preview"] = "4", ["dev.zed.Zed-Nightly"] = "4",
  ["chrome-linear.app__-Default"] = "5",
  discord = "6", chatgpt = "6", signal = "6", ["org.telegram.desktop"] = "6",
  ["com.obsproject.studio"] = "6", ["com.chatterino.chatterino"] = "6",
  ["chrome-localhost__-Default"] = "7", opendeck = "7",
  Bitwarden = "8", ["1password"] = "8", ["1Password"] = "8",
  steam = "9", steam_app_battlenet = "9", gamescope = "9", ["com.moonlight_stream.Moonlight"] = "9", wowupcf = "9",
  ["brave-browser"] = "10", ["md.obsidian.Obsidian"] = "10",
}

-- Apps that open several equal windows on purpose; every other app's extra windows (settings, dialogs) float.
C.multi_window = {
  foot = true, footclient = true, Alacritty = true, ["com.mitchellh.ghostty"] = true,
  ["dev.zed.Zed"] = true, ["dev.zed.Zed-Preview"] = true, ["dev.zed.Zed-Nightly"] = true,
  helium = true, ["brave-browser"] = true, steam_app_battlenet = true,
}

-- Update splashes open before the main window under the same class, so they must not count as the primary window.
C.splash_titles = { discord = "^Discord Updater$" }

-- Helium windows look identical to the compositor; the one named this in Helium (Name window…) is the main-screen one.
-- A named window's title is just its name, whatever tab is active, and Helium restores the name after a restart.
C.helium_main_title = "Main"

-- Passphrase prompts (SSH keys, keyrings) are app-independent, so they always ask on the main monitor.
C.password_prompt = { ["gcr-prompter"] = true, pinentry = true, ["pinentry-gtk"] = true, ["pinentry-qt"] = true, ["Pinentry-gtk"] = true }

return C
