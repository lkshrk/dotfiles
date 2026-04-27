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
          -- Hidden noise (shown by fd --hidden but not useful)
          '%.DS_Store',
          '%.env$',
          '%.env%.',
          '%.idea/',
          '%.vscode/',
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
    local entry_display = require 'telescope.pickers.entry_display'

    -- Git-aware find_files: dirty files highlighted in a different color
    local function get_git_dirty_files()
      local dirty = {}
      local handle = io.popen 'git status --porcelain 2>/dev/null'
      if handle then
        for line in handle:lines() do
          -- status is first 2 chars, then a space, then the path
          local path = line:sub(4)
          -- handle renames: "R  old -> new"
          local arrow = path:find ' %-> '
          if arrow then
            path = path:sub(arrow + 4)
          end
          dirty[path] = line:sub(1, 2)
        end
        handle:close()
      end
      return dirty
    end

    local function make_git_entry_maker(opts)
      local make_entry = require 'telescope.make_entry'
      local default_maker = make_entry.gen_from_file(opts)
      local dirty = get_git_dirty_files()

      return function(filepath)
        local entry = default_maker(filepath)
        local original_display = entry.display

        entry.display = function(e)
          local text, highlights = original_display(e)

          if dirty[e.value] or dirty[e.ordinal] then
            -- Override all highlights to git-changed color
            highlights = { { { 0, #text }, 'GitSignsChange' } }
          end

          return text, highlights
        end

        return entry
      end
    end

    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    local find_files = function()
      builtin.find_files {
        hidden = true,
        find_command = { 'fd', '--type', 'f', '--hidden', '--strip-cwd-prefix' },
        entry_maker = make_git_entry_maker {},
      }
    end
    vim.keymap.set('n', '<leader>sf', find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<C-f>', find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sc', builtin.git_status, { desc = '[S]earch Git [C]hanges' })
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
