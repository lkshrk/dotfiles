-- [[ Global keymaps — :help vim.keymap.set() ]]

-- Clear search highlight
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostics
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode with double-escape.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Split navigation
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Buffer cycling ]]
-- Note: <C-x> shadows decrement-number.
vim.keymap.set('n', '<leader>n', ':bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<leader>p', ':bprev<CR>', { desc = 'Previous buffer' })

-- Close buffer while keeping window layout intact.
vim.keymap.set('n', '<C-x>', function()
  vim.cmd 'bp'
  vim.cmd 'bd #'
end, { desc = 'Close buffer' })

-- [[ Clipboard / register shortcuts ]]
vim.keymap.set({ 'n', 'v' }, 'y', '"+y')
vim.keymap.set('n', 'yy', '"+yy')

vim.keymap.set({ 'n', 'v' }, 'p', '"+p')
vim.keymap.set({ 'n', 'v' }, 'P', '"+P')

-- Delete without polluting registers; x cuts to system clipboard.
vim.keymap.set({ 'n', 'v' }, 'd', '"_d')
vim.keymap.set({ 'n', 'v' }, 'c', '"_c')
vim.keymap.set({ 'n', 'v' }, 'x', '"+d')
vim.keymap.set('n', 'xx', '"+dd')

vim.keymap.set({ 'n', 'v' }, '<leader>d', '"+d')
vim.keymap.set({ 'n', 'v' }, '<leader>c', '"+c')
vim.keymap.set({ 'n', 'v' }, '<leader>x', '"+x')
