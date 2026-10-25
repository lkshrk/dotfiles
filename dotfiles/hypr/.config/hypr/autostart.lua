-- Without --background the daemon opens its UI in the default browser on every start.
o.launch_on_start("pipeweaver-daemon --background")
o.launch_on_start("opendeck")
-- Terminal-specific Cmd mappings from ~/.config/keyd/app.conf; needs the keyd group.
o.exec_on_start("keyd-application-mapper -d")

local session = os.getenv("HOME") .. "/.config/hypr/scripts/session"
o.exec_on_start(session .. " restore")
-- Debounced so login restores and Omarchy's close-all before shutdown save once, after things settle.
hl.on("window.open", function() hl.exec_cmd(session .. " save-later") end)
hl.on("window.close", function() hl.exec_cmd(session .. " save-later") end)
