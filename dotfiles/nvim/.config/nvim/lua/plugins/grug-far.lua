return {
  'MagicDuck/grug-far.nvim',
  cmd = 'GrugFar',
  keys = {
    {
      '<leader>sR',
      function()
        require('grug-far').open()
      end,
      desc = '[S]earch & [R]eplace in project',
    },
    {
      '<leader>sR',
      function()
        require('grug-far').with_visual_selection()
      end,
      mode = 'v',
      desc = '[S]earch & [R]eplace selection',
    },
    {
      '<leader>sb',
      function()
        require('grug-far').open { prefills = { paths = vim.fn.expand '%' } }
      end,
      desc = '[S]earch & replace in [b]uffer',
    },
  },
  opts = {},
}
