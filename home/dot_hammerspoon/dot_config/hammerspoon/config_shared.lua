-- Baseline values shared across all hosts. Per-host modules may extend or
-- override these; for appHotkeys the merge is per-key (host wins on conflict).

return {
  appHotkeys = {
    e = "Zed",
    n = "Obsidian",
    s = "Signal",
    t = "Ghostty",
  },
}
