-- [[ Autocommands — :help lua-guide-autocommands ]]

vim.api.nvim_create_autocmd({ 'BufEnter', 'DirChanged' }, {
  desc = 'Set window title to .nvim. <project>',
  group = vim.api.nvim_create_augroup('window-title', { clear = true }),
  callback = function()
    vim.opt.titlestring = '.nvim. ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
  end,
})

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
