return {
  'stevearc/overseer.nvim',
  cmd = {
    'OverseerClose',
    'OverseerOpen',
    'OverseerRun',
    'OverseerShell',
    'OverseerTaskAction',
    'OverseerToggle',
  },
  keys = {
    { '<leader>oo', '<cmd>OverseerToggle bottom<CR>', desc = 'Overseer Toggle' },
    { '<leader>or', '<cmd>OverseerRun<CR>', desc = 'Overseer Run Task' },
    { '<leader>oa', '<cmd>OverseerTaskAction<CR>', desc = 'Overseer Task Action' },
  },
  opts = {
    dap = true,
    output = {
      use_terminal = true,
      preserve_output = true,
    },
    task_list = {
      direction = 'bottom',
      min_height = 8,
      max_height = { 16, 0.25 },
    },
  },
}
