local function setup_telescope()
  -- Shim: telescope 0.1.x previewer calls nvim-treesitter.parsers.{ft_to_lang,
  -- get_parser} and nvim-treesitter.configs.{is_enabled,get_module}, which
  -- were removed in nvim-treesitter's main-branch rewrite. Inject fallbacks
  -- via package.loaded before telescope's previewer utils are required.
  local ok_p, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
  if ok_p and type(ts_parsers) == 'table' then
    if ts_parsers.ft_to_lang == nil then
      ts_parsers.ft_to_lang = function(ft)
        return vim.treesitter.language.get_lang(ft) or ft
      end
    end
    if ts_parsers.get_parser == nil then
      ts_parsers.get_parser = function(bufnr, lang)
        local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
        if not ok or not parser then
          return nil
        end
        -- Telescope hands the raw parser straight to
        -- `vim.treesitter.highlighter.new`, which indexes the parser's
        -- internal tree. Force a parse first so the tree exists.
        pcall(parser.parse, parser)
        return parser
      end
    end
  end

  if not package.loaded['nvim-treesitter.configs'] then
    package.loaded['nvim-treesitter.configs'] = {
      -- Telescope calls this before creating the treesitter highlighter.
      -- We must return false in any case where the highlighter would then
      -- fail — otherwise `highlighter.lua` blows up on a nil tree. Guard:
      --   1. lang must be non-empty
      --   2. parser must load for that lang
      --   3. a parser must be obtainable for the buffer and actually parse
      is_enabled = function(_, lang, bufnr)
        if type(lang) ~= 'string' or lang == '' then
          return false
        end
        if not pcall(vim.treesitter.language.add, lang) then
          return false
        end
        local buf = bufnr or 0
        if not vim.api.nvim_buf_is_valid(buf) then
          return false
        end
        local ok_parser, parser = pcall(vim.treesitter.get_parser, buf, lang)
        if not ok_parser or not parser then
          return false
        end
        local ok_parse, trees = pcall(function()
          return parser:parse()
        end)
        if not ok_parse or type(trees) ~= 'table' or #trees == 0 then
          return false
        end
        return true
      end,
      get_module = function(_)
        return { additional_vim_regex_highlighting = false }
      end,
    }
  end

  local actions = require 'telescope.actions'

  require('telescope').setup {
    defaults = {
      -- Avoid stray "A" in prompt on Neovim 0.12 (see frecency() above).
      initial_mode = 'normal',
      -- Show filename first, path (greyed) after — boosts basename match weight visually and in scoring.
      path_display = { 'filename_first' },
      -- --follow: stowed dotfiles are symlinks; rg skips them by default.
      vimgrep_arguments = {
        'rg',
        '--color=never',
        '--no-heading',
        '--with-filename',
        '--line-number',
        '--column',
        '--smart-case',
        '--follow',
      },
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
      frecency = {
        default_workspace = 'CWD',
        show_scores = false,
        -- Unindexed scan must follow symlinks too (stowed dotfiles).
        workspace_scan_cmd = { 'fd', '--type', 'f', '--follow', '--hidden', '--exclude', '.git', '.' },
      },
    },
  }

  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')
  pcall(require('telescope').load_extension, 'frecency')
end

local function get_git_dirty_files()
  local dirty = {}
  local handle = io.popen 'git status --porcelain 2>/dev/null'
  if handle then
    for line in handle:lines() do
      local path = line:sub(4)
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

local function git_hl_for_status(status)
  if status:match '%?' then
    return 'GitSignsAdd'
  end
  if status:match 'A' then
    return 'GitSignsAdd'
  end
  if status:match 'D' then
    return 'GitSignsDelete'
  end
  return 'GitSignsChange'
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
      local status = dirty[e.value] or dirty[e.ordinal]

      if status then
        highlights = { { { 0, #text }, git_hl_for_status(status) } }
      end

      return text, highlights
    end

    return entry
  end
end

local function find_files()
  require('telescope.builtin').find_files {
    hidden = true,
    -- --follow: stowed dotfiles are symlinks; --type f alone drops them.
    find_command = { 'fd', '--type', 'f', '--follow', '--hidden', '--strip-cwd-prefix' },
    entry_maker = make_git_entry_maker {},
  }
end

local function frecency()
  -- Telescope 0.1.x + Neovim 0.12: insert-mode pickers feedkeys("A") to place
  -- the cursor, but that keystroke lands as literal prompt text instead.
  require('telescope').extensions.frecency.frecency {
    workspace = 'CWD',
    default_text = '',
    initial_mode = 'normal',
  }
  -- Enter insert mode without re-triggering the broken "A" cursor placement.
  vim.defer_fn(function()
    if vim.fn.mode() == 'n' then
      vim.api.nvim_feedkeys('i', 'n', true)
    end
  end, 0)
end

return {
  'nvim-telescope/telescope.nvim',
  cmd = 'Telescope',
  module = 'telescope',
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-telescope/telescope-frecency.nvim' },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  keys = {
    { '<leader>sh', function() require('telescope.builtin').help_tags() end, desc = '[S]earch [H]elp' },
    { '<leader>sk', function() require('telescope.builtin').keymaps() end, desc = '[S]earch [K]eymaps' },
    { '<leader>sf', find_files, desc = '[S]earch [F]iles' },
    { '<C-f>', frecency, desc = 'Find Files (frecency)' },
    { '<leader>ss', function() require('telescope.builtin').builtin() end, desc = '[S]earch [S]elect Telescope' },
    { '<leader>sw', function() require('telescope.builtin').grep_string() end, desc = '[S]earch current [W]ord' },
    { '<leader>sg', function() require('telescope.builtin').live_grep() end, desc = '[S]earch by [G]rep' },
    { '<C-S-f>', function() require('telescope.builtin').live_grep() end, desc = 'Search file contents' },
    { '<leader>sd', function() require('telescope.builtin').diagnostics() end, desc = '[S]earch [D]iagnostics' },
    { '<leader>sc', function() require('telescope.builtin').git_status() end, desc = '[S]earch Git [C]hanges' },
    { '<leader>sr', function() require('telescope.builtin').resume() end, desc = '[S]earch [R]esume' },
    { '<leader>s.', function() require('telescope.builtin').oldfiles() end, desc = '[S]earch Recent Files ("." for repeat)' },
    { '<leader><leader>', function() require('telescope.builtin').buffers() end, desc = '[ ] Find existing buffers' },
    {
      '<leader>/',
      function()
        require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end,
      desc = '[/] Fuzzily search in current buffer',
    },
    {
      '<leader>s/',
      function()
        require('telescope.builtin').live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end,
      desc = '[S]earch [/] in Open Files',
    },
    {
      '<leader>sn',
      function()
        require('telescope.builtin').find_files { cwd = vim.fn.stdpath 'config' }
      end,
      desc = '[S]earch [N]eovim files',
    },
  },
  config = setup_telescope,
}