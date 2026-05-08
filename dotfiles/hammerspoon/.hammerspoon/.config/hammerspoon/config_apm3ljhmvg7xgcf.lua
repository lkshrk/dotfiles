return {
  primaryLabels   = { "bus", "stack", "priv" },
  secondaryLabels = {},

  appRules = {
    ["Microsoft Teams"]   = "bus",
    ["Microsoft Outlook"] = "bus",
    ["Ghostty"]           = "stack",
    ["Zed"]               = "stack",
    ["Obsidian"]          = "stack",
    ["Microsoft Edge"]    = "stack",
    ["Vivaldi"]           = "priv",
    ["Signal"]            = "priv",
  },

  appHotkeys = {
    b = "Microsoft Edge",
    o = "Microsoft Outlook",
    i = "Microsoft Teams",
  },
}
