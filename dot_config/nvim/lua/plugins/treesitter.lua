return {
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    branch = 'main', -- importante!
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup()

      local mason_bin = vim.fn.stdpath 'data' .. '/mason/bin'
      if vim.uv.fs_stat(vim.fs.joinpath(mason_bin, 'tree-sitter')) and not vim.env.PATH:find(mason_bin, 1, true) then
        vim.env.PATH = mason_bin .. ':' .. vim.env.PATH
      end

      if vim.fn.executable 'tree-sitter' == 1 then
        require('nvim-treesitter').install { 'c_sharp', 'razor', 'html' }
      else
        vim.notify('tree-sitter executable not found; run :MasonToolsInstallSync and restart Neovim to install C#/Razor parsers', vim.log.levels.WARN)
      end

      vim.treesitter.language.register('c_sharp', { 'cs' })
      vim.treesitter.language.register('razor', { 'razor', 'cshtml' })

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-dotnet', { clear = true }),
        pattern = { 'cs', 'razor', 'cshtml' },
        callback = function()
          pcall(vim.treesitter.start)
          vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.wo.foldmethod = 'expr'
          vim.wo.foldlevel = 99
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
