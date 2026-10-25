dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Keeps Omarchy's window-manager bindings, drops the ones for its preinstalled apps.
omarchy_preinstalled_bindings = false

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.rules")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

require("default.hypr.toggles")
