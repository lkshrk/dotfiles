-- Loader: merges shared defaults with the per-host placement/namespace
-- mapping. Selects the host module by `hostname -s` (matches hosts/*.conf
-- naming used by install.sh). Falls back to config_default.lua.

local M = {}

local function shortHostname()
  local h = io.popen("hostname -s")
  if not h then return "default" end
  local name = (h:read("*l") or ""):gsub("%s+$", "")
  h:close()
  return name
end

local function normalize(name)
  return (name or ""):lower():gsub("[^%w]", "_")
end

-- Shallow merge; appHotkeys is merged per-key so host overrides individual bindings.
local function mergeInto(dst, src)
  for k, v in pairs(src) do
    if k == "appHotkeys" and type(dst.appHotkeys) == "table" and type(v) == "table" then
      for hk, hv in pairs(v) do dst.appHotkeys[hk] = hv end
    else
      dst[k] = v
    end
  end
end

mergeInto(M, require("config_shared"))

local hostModule = "config_" .. normalize(shortHostname())
local ok, hostCfg = pcall(require, hostModule)
if ok then
  mergeInto(M, hostCfg)
else
  print("[hammerspoon] no host config '" .. hostModule .. "', using config_default")
  mergeInto(M, require("config_default"))
end

M.managedApps = M.managedApps or { Vivaldi = true }
for app in pairs(M.appRules or {}) do M.managedApps[app] = true end

return M
