-- Extra autostart processes.
-- Without --background the daemon opens its UI in the default browser on every start.
o.launch_on_start("pipeweaver-daemon --background")

-- Reopen last session's apps and keep the list current as windows open and close.
local session = os.getenv("HOME") .. "/.config/hypr/scripts/session"
o.exec_on_start(session .. " restore")
-- Debounced so login restores and Omarchy's close-all before shutdown save once, after things settle.
hl.on("window.open", function() hl.exec_cmd(session .. " save-later") end)
hl.on("window.close", function() hl.exec_cmd(session .. " save-later") end)
