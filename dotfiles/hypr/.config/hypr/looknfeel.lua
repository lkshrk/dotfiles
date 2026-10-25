hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    -- Opaque, so unfocused windows keep a visible edge against each other.
    col = { inactive_border = "rgb(45475a)" },
    -- Drag any window edge to resize, as on macOS.
    resize_on_border = true,
  },
})
