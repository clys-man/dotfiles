return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup {
      flavour = 'mocha',
      transparent_background = false,
      custom_highlights = function(colors)
        return {
          FloatBorder = { fg = colors.blue },
          CursorLineNr = { fg = colors.blue, style = { 'bold' } },
          PmenuSel = { bg = colors.surface1, fg = colors.blue },
          TelescopeBorder = { fg = colors.blue },
        }
      end,
    }
    vim.cmd.colorscheme 'catppuccin'
    vim.cmd.hi 'Comment gui=none'
  end,
}
