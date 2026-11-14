return {
  'echasnovski/mini.nvim',
  event = 'VeryLazy',
  config = function()
    -- Better Around/Inside textobjects: va), yinq, ci', etc.
    require('mini.ai').setup { n_lines = 500 }
    -- Add/delete/replace surroundings: saiw), sd', sr)'
    require('mini.surround').setup()
    -- Show open buffers as tabs
    require('mini.tabline').setup()

    local statusline = require 'mini.statusline'
    statusline.setup { use_icons = vim.g.have_nerd_font }

    ---@diagnostic disable-next-line: duplicate-set-field
    statusline.section_location = function()
      return '%2l:%-2v'
    end
  end,
}
