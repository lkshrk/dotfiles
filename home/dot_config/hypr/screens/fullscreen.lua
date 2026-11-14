-- Hyprland lets a focused floating window stay drawn over a fullscreen one; refocusing the fullscreen window sends them back under it.
hl.on("window.active", function(w)
  if not w or w.fullscreen == 0 or not w.workspace then return end
  for _, other in ipairs(hl.get_workspace_windows(w.workspace.name)) do
    if other ~= w and other.floating and not other.pinned and other.allowed_over_fullscreen then
      hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = other }))
    end
  end
end)
