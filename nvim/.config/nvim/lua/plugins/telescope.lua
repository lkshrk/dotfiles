return {
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local actions = require 'telescope.actions'

    require('telescope').setup {
      defaults = {
        -- Show filename first, path (greyed) after — boosts basename match weight visually and in scoring.
        path_display = { 'filename_first' },
        file_ignore_patterns = {
          'node_modules',
          '%.git/',
          'dist',
          'build',
          'coverage',
          'target',
          '.next',
          '.svelte%-kit',
          '%.DS_Store',
          '%.cache/',
          -- macOS Library dirs (user + system)
          '^Library/',
          '^/Library/',
          '/Users/[^/]+/Library/',
        },
        mappings = {
          i = {
            ['<C-d>'] = actions.preview_scrolling_down,
            ['<C-u>'] = actions.preview_scrolling_up,
            ['<C-x>'] = actions.delete_buffer,
          },
          n = {
            ['<C-d>'] = actions.preview_scrolling_down,
            ['<C-u>'] = actions.preview_scrolling_up,
            ['dd'] = actions.delete_buffer,
            ['<C-x>'] = actions.delete_buffer,
          },
        },
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
      },
    }

    pcall(require('telescope').load_extension, 'fzf')
    pcall(require('telescope').load_extension, 'ui-select')

    local builtin = require 'telescope.builtin'
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    local find_files = function()
      builtin.find_files {
        hidden = true,
        find_command = { 'fd', '--type', 'f', '--hidden', '--strip-cwd-prefix' },
      }
    end
    vim.keymap.set('n', '<leader>sf', find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<C-f>', find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

    vim.keymap.set('n', '<leader>/', function()
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    vim.keymap.set('n', '<leader>s/', function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end, { desc = '[S]earch [/] in Open Files' })

    vim.keymap.set('n', '<leader>sn', function()
      builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })
  end,
}
