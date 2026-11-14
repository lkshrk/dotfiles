local theme = require 'config.omarchy_theme'

local specs = {
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false },
        },
      }
      theme.apply()
      theme.watch()
    end,
  },
}

return vim.list_extend(specs, theme.plugin_specs())
