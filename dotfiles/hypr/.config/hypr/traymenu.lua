-- Wine tray menus open as windows of the app, so the app's workspace and frame rules would pull them away from the bar.
local D = require("hypr.screens.decide")

local EXPECT_MS = 2000
local made, expected = 0, nil

-- Called by the tray's tray-context-menu helper through hyprctl eval, just before it asks the app for its menu.
function tray_menu_expected(pid)
  local class, known = nil, {}
  for _, w in ipairs(hl.get_windows()) do
    known[w.address] = true
    if w.pid == pid and not class and w.class and w.class ~= "" then class = w.class end
  end
  if not class then return end
  local token = { pid = pid, known = known }
  expected = token
  made = made + 1
  local name = "tray-menu-" .. made
  -- Only static effects: they apply when a window maps, so the app's open windows keep their place.
  hl.window_rule({
    name = name,
    match = { class = "^" .. D.regex_escape(class) .. "$" },
    float = true,
    workspace = "unset",
    move = { "(cursor_x-window_w*0.5)", "(cursor_y)" },
  })
  require("hypr.screens.frames").suspend(class, EXPECT_MS)
  hl.timer(function()
    hl.window_rule({ name = name, enabled = false, match = { class = "^$" } })
    if expected == token then expected = nil end
  end, { timeout = EXPECT_MS, type = "oneshot" })
end

-- The tag keeps frames.lua from saving the menu as the app's frame and the slot logic from placing it.
hl.on("window.open_early", function(w)
  if not expected or not w or not w.address or w.pid ~= expected.pid or expected.known[w.address] then return end
  expected = nil
  hl.dispatch(hl.dsp.window.tag({ tag = "+tray-menu", window = w }))
end)
