local C = require("hypr.screens.config")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
-- Matched by serial so the layout survives port swaps; VRR in fullscreen only.
hl.monitor({ output = C.side, mode = "2560x1440@120", position = "0x815", scale = 1, transform = 1, vrr = 2 })
hl.monitor({ output = C.top, mode = "2560x1440@120", position = "1696x0", scale = 1, vrr = 2 })
hl.monitor({ output = C.main, mode = "3840x2160@240", position = "1440x1440", scale = 1.25, vrr = 2 })

-- GTK only honours whole numbers here, and XWayland windows stay unscaled so they stay crisp.
hl.env("GDK_SCALE", "1")
