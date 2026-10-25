---@meta
-- Types for Omarchy's Hyprland helper table `o` (/usr/share/omarchy/default/hypr/helpers.lua); it ships no stubs of its own.

---@class O.CommandSpec
---@field omarchy? string Runs `omarchy-launch-<name>`.
---@field launch? string Command started through uwsm-app.
---@field focus? string Window class to focus instead of launching again (with launch or webapp).
---@field webapp? string URL opened as a web app.

---@alias O.Dispatcher string|HL.Dispatcher|fun()|O.CommandSpec

---@class O.WindowMatch
---@field class? string
---@field title? string
---@field initial_class? string
---@field initial_title? string
---@field tag? string
---@field modal? boolean
---@field xwayland? boolean
---@field float? boolean
---@field fullscreen? boolean
---@field pin? boolean

---Set to false before Omarchy's defaults load to drop the bindings for its preinstalled apps and web apps.
---@type boolean?
omarchy_preinstalled_bindings = nil

---Set to false before Omarchy's defaults load to drop all of its bindings.
---@type boolean?
omarchy_default_bindings = nil

---@class O
o = {}

---@param value any
---@return string
function o.shell_quote(value) end

---@param command string
---@return boolean
function o.shell_succeeds(command) end

---@param command string
---@return boolean
function o.cmd_present(command) end

---@param command string
---@return boolean
function o.cmd_missing(command) end

---@return boolean
function o.preinstalled_bindings_enabled() end

---@param keys string Hyprland key combination, e.g. "SUPER + SHIFT + Q".
---@param description? string Shown in Omarchy's keybinding list.
---@param dispatcher O.Dispatcher
---@param options? HL.BindOptions
function o.bind(keys, description, dispatcher, options) end

---@param command string
---@return string
function o.launch(command) end

---@param command string
function o.exec_on_start(command) end

---@param command string
function o.launch_on_start(command) end

---@param url string
---@return string
function o.launch_webapp(url) end

---@param name string
---@param url string
---@return string
function o.launch_webapp_sole(name, url) end

---@param match string
---@param command string
---@return string
function o.launch_sole(match, command) end

---@param keys string
---@param description? string
---@param toggle string Name of an `omarchy-toggle-<name>` command.
---@param options? HL.BindOptions
function o.bind_toggle(keys, description, toggle, options) end

---@param message string
---@return string
function o.notify(message) end

---@param match string|O.WindowMatch Window class pattern, or a table of match fields.
---@param rules table Hyprland window rule fields.
function o.window(match, rules) end
