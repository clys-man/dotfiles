return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    'Issafalcon/neotest-dotnet',
  },
  keys = {
    {
      '<leader>tt',
      function()
        require('neotest').run.run()
      end,
      desc = 'Test: Run Nearest',
    },
    {
      '<leader>tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = 'Test: Run File',
    },
    {
      '<leader>ta',
      function()
        require('neotest').run.run { suite = true }
      end,
      desc = 'Test: Run Suite',
    },
    {
      '<leader>ts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = 'Test: Toggle Summary',
    },
    {
      '<leader>tq',
      function()
        require('neotest').output.open { enter = true }
      end,
      desc = 'Test: Show Output',
    },
    {
      '<leader>tQ',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = 'Test: Toggle Output Panel',
    },
    {
      '<leader>td',
      function()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = 'Test: Debug Nearest',
    },
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-dotnet' {
          dap = {
            adapter_name = 'netcoredbg',
            args = {
              justMyCode = false,
            },
          },
          discovery_root = 'project',
        },
      },
    }
  end,
}
