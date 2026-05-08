package.path = package.path .. ";" .. hs.configdir .. "/?.lua"

local state     = require("state")
local spaces    = require("spaces")
local app_rules = require("app_rules")
local layouts   = require("layouts")
local hotkeys   = require("hotkeys")

state.start()
spaces.start()
app_rules.start()
hotkeys.setup()

spaces.onReady(function()
  hs.timer.doAfter(2, function()
    app_rules.applyToExisting()
    layouts.applyAll()
  end)
end)

hs.alert.show("Hammerspoon loaded")
