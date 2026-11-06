hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    -- Opaque, so unfocused windows keep a visible edge against each other.
    col = { inactive_border = "rgb(45475a)" },
    extend_border_grab_area = 15,
  },
  decoration = { dim_special = 0.2 },
  -- Hyprland warps before a new window has a position, so a window opening onto another workspace threw the cursor to the side screen's corner.
  cursor = { no_warps = true, warp_on_change_workspace = 0 },
  render = { cm_auto_hdr = 1 },
})

for _, leaf in ipairs({ "specialWorkspace", "specialWorkspaceIn", "specialWorkspaceOut" }) do
  hl.animation({ leaf = leaf, enabled = true, speed = 3, bezier = "easeOutQuint", style = "slidevert" })
end
