package.path = "dotfiles/hypr/.config/?.lua;" .. package.path
local D = require("hypr.screens.decide")

local first = { address = "a", class = "linear", stable_id = 3, transient = false }
local second = { address = "b", class = "linear", stable_id = 7 }
assert(D.role(second, { first }, false) == "extra", "a later window of a single-window app is an extra")
assert(D.role(second, { first }, true) == "main", "multi-window apps have no extras")
assert(D.role(second, { { address = "a", class = "linear", stable_id = 3, transient = true } }, false) == "main",
  "a transient window does not make the next one an extra")
assert(D.role(second, {}, false) == "main", "the only window of an app is main")
assert(D.role(second, { { address = "c", class = "discord", stable_id = 1, transient = false } }, false) == "main",
  "windows of another app do not count")

assert(D.title_key("steam", "") == nil)
assert(D.title_key("steam", nil) == nil)
assert(D.title_key("steam", "Friends List") == "steam|Friends List")
assert(D.app_key("discord") == "discord|")

local frame = D.frame({ "10", "20", "300", "400" })
assert(frame.x == 10 and frame.y == 20 and frame.w == 300 and frame.h == 400)
assert(D.frame({ "10", "x" }) == nil)
assert(D.frame(nil) == nil)
local row = D.row(frame, 1000)
assert(row[1] == "10" and row[2] == "20" and row[3] == "300" and row[4] == "400" and row[5] == "1000")

assert(D.fits({ x = 100, y = 100, w = 200, h = 200 }, { x = 0, y = 0, w = 1000, h = 1000 }))
assert(not D.fits({ x = 100, y = 100, w = 200, h = 200 }, { x = 2000, y = 0, w = 1000, h = 1000 }),
  "a frame centred on another monitor does not fit")

assert(not D.drifted(frame, 11, 20, 300, 400), "two pixels of tolerance")
assert(D.drifted(frame, 50, 20, 300, 400))
assert(D.drifted(frame, 10, 20, 300, 500))

assert(D.app_frame_allowed("main", false))
assert(not D.app_frame_allowed("main", true))
assert(not D.app_frame_allowed("extra", false))
assert(not D.app_frame_allowed("pending", false))

assert(D.may_save_app("main", false, 12000, 10000))
assert(not D.may_save_app("main", false, 9000, 10000), "a short-lived window never becomes the app frame")
assert(not D.may_save_app("main", true, 12000, 10000))
assert(not D.may_save_app("extra", false, 12000, 10000))

local kept = D.prune({ a = { "1", "2", "3", "4" } }, 1000, 60 * 86400)
assert(kept.a and kept.a[5] == "1000", "prune keeps rows without timestamp")
local day = 86400
local pruned = D.prune({ b = { "1", "2", "3", "4", "100" }, c = { "1", "2", "3", "4", tostring(100 + 59 * day) } },
  100 + 61 * day, 60 * day)
assert(pruned.b == nil, "prune drops old rows")
assert(pruned.c ~= nil, "prune keeps recent rows")

assert(D.title_key(nil, "x") == nil, "a window without a class has no key")
assert(D.app_key(nil) == nil)
assert(D.title_key("steam", "a\tb") == nil, "tabs would break the TSV row")
assert(D.title_key("steam", "a\nb") == nil)

assert(D.regex_escape("Battle.net (beta) [x]+?*^$|{}\\") == "Battle\\.net \\(beta\\) \\[x\\]\\+\\?\\*\\^\\$\\|\\{\\}\\\\")

local monitors = { { name = "DP-1", x = 1440, y = 1440, w = 3072, h = 1728 }, { name = "DP-3", x = 1696, y = 0, w = 2560, h = 1440 } }
assert(D.monitor_for({ x = 2990, y = 1678, w = 1516, h = 934 }, monitors).name == "DP-1")
assert(D.monitor_for({ x = 9000, y = 9000, w = 10, h = 10 }, monitors) == nil, "a frame on no monitor has no rule")

local title_rule = D.frame_rule("steam_app_battlenet", "Battle.net", { x = 2990, y = 1678, w = 1516, h = 934 }, monitors[1])
assert(title_rule.match.class == "^steam_app_battlenet$")
assert(title_rule.match.title == "^Battle\\.net$")
assert(title_rule.size[1] == 1516 and title_rule.size[2] == 934)
assert(title_rule.move[1] == 1550 and title_rule.move[2] == 238, "move is monitor-local")
assert(title_rule.suppress_event == nil, "ignoring X11 configure requests makes Battle.net grab focus every few seconds")
assert(title_rule.float == nil, "frame rules never float a window themselves")

local app_rule = D.frame_rule("steam", nil, { x = 1500, y = 1500, w = 800, h = 600 }, monitors[1])
assert(app_rule.match.title == nil)

print("ok")
