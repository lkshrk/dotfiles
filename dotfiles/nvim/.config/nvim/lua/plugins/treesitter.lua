-- nvim-treesitter (neovim-treesitter fork, main branch rewrite)
-- Requires: tree-sitter CLI >= 0.26.1 (brew install tree-sitter), curl, C compiler.
-- Docs: https://github.com/neovim-treesitter/nvim-treesitter
return {
  'neovim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false, -- plugin does not support lazy-loading
  build = ':TSUpdate',
  dependencies = {
    'neovim-treesitter/treesitter-parser-registry',
  },
  config = function()
    local ensure = {
      'bash',
      'c',
      'diff',
      'html',
      'javascript',
      'json',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'python',
      'query',
      'toml',
      'tsx',
      'typescript',
      'vim',
      'vimdoc',
      'yaml',
    }

    -- install() is async and a no-op when parsers are already present.
    -- On fresh machines it needs the tree-sitter CLI; missing CLI is the
    -- usual reason nothing appears under <stdpath('data')>/site/parser/.
    require('nvim-treesitter').install(ensure)

    -- main branch has no setup() for features — enable per-buffer on FileType.
    local grp = vim.api.nvim_create_augroup('user.treesitter', { clear = true })
    vim.api.nvim_create_autocmd('FileType', {
      group = grp,
      callback = function(ev)
        local ft = ev.match
        if ft == '' or ft == 'ruby' then
          return -- keep vim regex highlight for ruby
        end
        local lang = vim.treesitter.language.get_lang(ft) or ft
        -- only enable if a parser is actually available for this lang
        local ok = pcall(vim.treesitter.language.add, lang)
        if not ok then
          return
        end
        pcall(vim.treesitter.start, ev.buf, lang)
        vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        vim.wo.foldmethod = 'expr'
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
