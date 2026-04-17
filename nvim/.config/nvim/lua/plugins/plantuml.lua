return {
  -- PlantUML syntax, ftdetect, folding
  { 'aklt/plantuml-syntax', ft = { 'plantuml' } },

  -- Live browser preview via local WebSocket server
  {
    'charlesnicholson/plantuml.nvim',
    ft = { 'plantuml' },
    opts = {
      auto_start = true,
      auto_update = true,
      http_port = 8764,
      auto_launch_browser = 'never',
      use_docker = true,
      docker_image = 'plantuml/plantuml-server:jetty',
      docker_port = 8080,
      docker_remove_on_stop = true,
    },
  },

  -- Markdown browser preview (kept for general markdown work)
  {
    'iamcco/markdown-preview.nvim',
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    ft = { 'markdown' },
    build = function()
      vim.fn['mkdp#util#install']()
    end,
  },
}
