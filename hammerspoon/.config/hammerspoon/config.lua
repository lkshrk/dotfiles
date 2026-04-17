local M = {}

M.appHotkeys = {
  b = "Vivaldi",
  c = "Chatterino",
  d = "Discord",
  e = "Zed",
  n = "Obsidian",
  o = "OBS",
  v = "Brave Browser",
  s = "Signal",
  t = "Ghostty",
  a = "ChatGPT",
}

M.primaryLabels   = { "main", "stack", "remote" }
M.secondaryLabels = { "comms", "stream" }

M.appRules = {
  ["Ghostty"]           = "stack",
  ["Zed"]               = "stack",
  ["Moonlight"]         = "remote",
  ["League of Legends"] = "remote",
  ["Discord"]           = "comms",
  ["ChatGPT"]           = "comms",
  ["Signal"]            = "comms",
  ["Messages"]          = "comms",
  ["Chatterino"]        = "comms",
  ["OBS"]               = "comms",
  ["Brave Browser"]     = "comms",
  ["Obsidian"]          = "comms",
  ["Stream Deck"]       = "stream",
  ["Elgato Wave Link"]  = "stream",
}

M.managedApps = { Vivaldi = true }
for app in pairs(M.appRules) do M.managedApps[app] = true end

return M
