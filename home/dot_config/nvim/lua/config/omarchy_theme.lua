-- [[ Colorscheme from the current Omarchy theme, tokyonight-night without one ]]
local M = {}

local uv = vim.uv
local fallback = 'tokyonight-night'
local omarchy = vim.env.OMARCHY_PATH or '/usr/share/omarchy'
local current = vim.env.HOME .. '/.local/state/omarchy/current'
local theme_file = current .. '/theme/neovim.lua'

local function read(path)
  if not uv.fs_stat(path) then
    return {}
  end
  local ok, spec = pcall(dofile, path)
  if not ok or type(spec) ~= 'table' then
    return {}
  end
  return type(spec[1]) == 'string' and { spec } or spec
end

local function name_of(spec)
  if type(spec) == 'table' and type(spec[1]) == 'string' and spec[1] ~= 'LazyVim/LazyVim' then
    return spec.name or spec[1]:match '[^/]+$'
  end
end

local function parse(specs)
  local theme = {}
  for _, spec in ipairs(specs) do
    if type(spec) == 'table' and spec[1] == 'LazyVim/LazyVim' then
      local opts = spec.opts
      if type(opts) == 'table' and type(opts.colorscheme) == 'string' then
        theme.colorscheme = opts.colorscheme
      end
    elseif not theme.plugin and name_of(spec) then
      theme.plugin = spec
    end
  end
  return theme
end

-- Every packaged theme's plugin is registered lazily, so a live switch never waits on a restart.
function M.plugin_specs()
  local specs, seen = {}, { ['tokyonight.nvim'] = true }
  if not uv.fs_stat(current) then
    return specs
  end
  local paths = { theme_file, omarchy .. '/default/themed/neovim.lua.tpl' }
  vim.list_extend(paths, vim.fn.glob(omarchy .. '/themes/*/neovim.lua', false, true))
  for _, path in ipairs(paths) do
    for _, spec in ipairs(read(path)) do
      local name = name_of(spec)
      if name and not seen[name] then
        seen[name] = true
        specs[#specs + 1] = {
          spec[1],
          name = name,
          branch = spec.branch,
          tag = spec.tag,
          version = spec.version,
          dependencies = spec.dependencies,
          lazy = true,
        }
      end
    end
  end
  return specs
end

local function load(spec)
  local plugin = require('lazy.core.config').plugins[name_of(spec)]
  if not (plugin and plugin._.installed) then
    return false
  end
  local configure = type(spec.opts) == 'table' or type(spec.config) == 'function'
  if configure and plugin._.loaded then
    require('lazy.core.util').walkmods(plugin.dir .. '/lua', function(mod)
      package.loaded[mod] = nil
    end)
  end
  require('lazy').load { plugins = { plugin.name } }
  if type(spec.config) == 'function' then
    return pcall(spec.config, plugin, spec.opts)
  end
  if type(spec.opts) == 'table' then
    local main = require('lazy.core.loader').get_main(plugin)
    if main then
      pcall(function()
        require(main).setup(spec.opts)
      end)
    end
  end
  return true
end

function M.apply(reload)
  local theme = parse(read(theme_file))
  local loaded = theme.plugin == nil or load(theme.plugin)
  if reload then
    vim.cmd 'highlight clear'
    vim.o.background = 'dark'
  end
  local ok = false
  if theme.colorscheme then
    ok = loaded and pcall(vim.cmd.colorscheme, theme.colorscheme)
  elseif theme.plugin and type(theme.plugin.config) == 'function' then
    ok = loaded
  end
  if not ok then
    if theme.colorscheme then
      vim.notify(('Omarchy colorscheme %s is unavailable, using %s'):format(theme.colorscheme, fallback), vim.log.levels.WARN)
    end
    vim.cmd.colorscheme(fallback)
  end
end

-- omarchy-theme-set swaps the theme directory and then rewrites theme.name.
function M.watch()
  if M.watcher or not uv.fs_stat(current) then
    return
  end
  local timer = assert(uv.new_timer())
  M.watcher = assert(uv.new_fs_event())
  M.watcher:start(current, {}, function(err, filename)
    if err or filename ~= 'theme.name' then
      return
    end
    timer:stop()
    timer:start(
      150,
      0,
      vim.schedule_wrap(function()
        M.apply(true)
      end)
    )
  end)
end

return M
