local C = require("hypr.screens.config")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
-- Matched by serial so the layout survives port swaps; VRR in fullscreen only.
hl.monitor({ output = C.side, mode = "2560x1440@120", position = "0x815", scale = 1, transform = 1, vrr = 2 })
hl.monitor({ output = C.top, mode = "2560x1440@120", position = "1696x0", scale = 1, vrr = 2 })
-- VRR always on (Adaptive-Sync on in the monitor's menu): at fixed 240 Hz every fourth desktop frame missed its refresh.
hl.monitor({ output = C.main, mode = "3840x2160@240", position = "1440x1440", scale = 1.25, vrr = 1 })

-- Xwayland has no primary output, so Wine would call the screen at its 0,0 (the portrait one) primary; Xwayland forgets it on every reconnect.
local function xwayland_primary()
  local m = hl.get_monitor(C.main)
  if not m then return end
  hl.exec_cmd("sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do sleep 2; DISPLAY=${DISPLAY:-:0} xrandr --output "
    .. m.name .. " --primary 2>/dev/null && exit; done'")
end
hl.timer(xwayland_primary, { timeout = 3000, type = "oneshot" })
for _, event in ipairs({ "monitor.added", "monitor.layout_changed" }) do
  hl.on(event, xwayland_primary)
end

-- GTK only honours whole numbers here, and XWayland windows stay unscaled so they stay crisp.
hl.env("GDK_SCALE", "1")
