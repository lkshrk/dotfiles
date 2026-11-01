hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    -- Opaque, so unfocused windows keep a visible edge against each other.
    col = { inactive_border = "rgb(45475a)" },
    -- Drag any window edge to resize, as on macOS.
    resize_on_border = true,
  },
  -- Hyprland warps before a new window has a position, so a window opening onto another workspace threw the cursor to the side screen's corner.
  cursor = { warp_on_change_workspace = 0 },
})
