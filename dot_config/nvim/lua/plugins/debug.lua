-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<leader>du',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },

    {
      '<leader>dB',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Breakpoint Condition',
    },
    {
      '<leader>db',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Toggle Breakpoint',
    },
    {
      '<leader>dc',
      function()
        require('dap').continue()
      end,
      desc = 'Run/Continue',
    },
    {
      '<leader>da',
      function()
        require('dap').continue { before = get_args }
      end,
      desc = 'Run with Args',
    },
    {
      '<leader>dC',
      function()
        require('dap').run_to_cursor()
      end,
      desc = 'Run to Cursor',
    },
    {
      '<leader>dg',
      function()
        require('dap').goto_()
      end,
      desc = 'Go to Line (No Execute)',
    },
    {
      '<leader>di',
      function()
        require('dap').step_into()
      end,
      desc = 'Step Into',
    },
    {
      '<leader>dj',
      function()
        require('dap').down()
      end,
      desc = 'Down',
    },
    {
      '<leader>dk',
      function()
        require('dap').up()
      end,
      desc = 'Up',
    },
    {
      '<leader>dl',
      function()
        require('dap').run_last()
      end,
      desc = 'Run Last',
    },
    {
      '<leader>do',
      function()
        require('dap').step_out()
      end,
      desc = 'Step Out',
    },
    {
      '<leader>dO',
      function()
        require('dap').step_over()
      end,
      desc = 'Step Over',
    },
    {
      '<leader>dP',
      function()
        require('dap').pause()
      end,
      desc = 'Pause',
    },
    {
      '<leader>dr',
      function()
        require('dap').repl.toggle()
      end,
      desc = 'Toggle REPL',
    },
    {
      '<leader>ds',
      function()
        require('dap').session()
      end,
      desc = 'Session',
    },
    {
      '<leader>dt',
      function()
        require('dap').terminate()
      end,
      desc = 'Terminate',
    },
    {
      '<leader>dw',
      function()
        require('dap.ui.widgets').hover()
      end,
      desc = 'Widgets',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {
        netcoredbg = function(config)
          config.configurations = {
            {
              type = 'coreclr',
              name = 'Launch',
              request = 'launch',
              program = function()
                return vim.fn.input('Path to dll: ', vim.fn.getcwd() .. '/bin/Debug/', 'file')
              end,
            },
            {
              type = 'coreclr',
              name = 'Attach',
              request = 'attach',
              processId = require('dap.utils').pick_process,
            },
          }
          require('mason-nvim-dap').default_setup(config)
        end,

        php = function(config)
          config.configurations = {
            {
              type = 'php',
              request = 'launch',
              name = 'Listen for Xdebug',
              port = 9003,
              pathMappings = {
                -- For some reason xdebug sometimes fails for me, depending on me
                -- using herd or docker. To get it to work, change the order of the mappings.
                -- The first mapping should be the one that you are actively using.
                -- This only started recently, so I don't know what changed.
                ['${workspaceFolder}'] = '${workspaceFolder}',
                ['/var/www/html'] = '${workspaceFolder}',
              },
            },
          }
          require('mason-nvim-dap').default_setup(config) -- don't forget this!
        end,
      },

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'delve',
        'php',
        'python',
        'netcoredbg',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters from Nerd Fonts.
      icons = { expanded = '', collapsed = '', current_frame = '' },
      controls = {
        icons = {
          pause = '',
          play = '',
          step_into = '',
          step_over = '',
          step_out = '',
          step_back = '',
          run_last = '',
          terminate = '',
          disconnect = '',
        },
      },
    }

    -- Change breakpoint icons
    vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#66ccff' })
    vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })

    local breakpoint_icons = {
      Breakpoint = '◉',
      BreakpointCondition = '',
      BreakpointRejected = '',
      LogPoint = '',
      Stopped = '',
    }

    for type, icon in pairs(breakpoint_icons) do
      local tp = 'Dap' .. type
      local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
      vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    dap.adapters.coreclr = {
      type = 'executable',
      command = vim.fn.stdpath 'data' .. '/mason/bin/netcoredbg',
      args = { '--interpreter=vscode' },
    }

    dap.adapters.netcoredbg = dap.adapters.coreclr

    local dotnet = require 'core.dotnet'

    local function read_project_value(project, tag)
      local ok, lines = pcall(vim.fn.readfile, project)
      if not ok then
        return nil
      end

      return table.concat(lines, '\n'):match('<' .. tag .. '>%s*(.-)%s*</' .. tag .. '>')
    end

    local function target_framework(project)
      local framework = read_project_value(project, 'TargetFramework')
      if framework and framework ~= '' then
        return framework
      end

      local frameworks = read_project_value(project, 'TargetFrameworks')
      if frameworks and frameworks ~= '' then
        return vim.split(frameworks, ';', { trimempty = true })[1]
      end
    end

    local function assembly_name(project)
      local name = read_project_value(project, 'AssemblyName')
      if name and name ~= '' then
        return name
      end

      return vim.fn.fnamemodify(project, ':t:r')
    end

    local function find_project_dll(project)
      local project_dir = vim.fs.dirname(project)
      local framework = target_framework(project)
      local name = assembly_name(project)

      if framework then
        local dll = vim.fs.joinpath(project_dir, 'bin', 'Debug', framework, name .. '.dll')
        if vim.uv.fs_stat(dll) then
          return dll
        end
      end

      local dlls = vim.fn.globpath(project_dir, 'bin/Debug/net*/*.dll', false, true)
      table.sort(dlls)
      for _, dll in ipairs(dlls) do
        if vim.fn.fnamemodify(dll, ':t:r') == name then
          return dll
        end
      end

      if #dlls == 1 then
        return dlls[1]
      end

      if #dlls > 1 then
        return vim.fn.input('Path to dll: ', dlls[1], 'file')
      end

      return vim.fn.input('Path to dll: ', vim.fs.joinpath(project_dir, 'bin', 'Debug') .. '/', 'file')
    end

    local function build_dotnet_project(project, on_done)
      vim.notify('Building ' .. vim.fn.fnamemodify(project, ':~:.'), vim.log.levels.INFO)

      if not vim.system then
        local output = vim.fn.system { 'dotnet', 'build', project, '-c', 'Debug' }
        local ok = vim.v.shell_error == 0
        if not ok then
          vim.notify(output, vim.log.levels.ERROR)
        end

        on_done(ok)
        return
      end

      vim.system({ 'dotnet', 'build', project, '-c', 'Debug' }, { text = true }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            vim.notify(vim.trim((result.stdout or '') .. '\n' .. (result.stderr or '')), vim.log.levels.ERROR)
          end

          on_done(result.code == 0)
        end)
      end)
    end

    local function resume_dap_config(co, config)
      vim.schedule(function()
        local ok, err = coroutine.resume(co, config)
        if not ok then
          vim.notify(err, vim.log.levels.ERROR)
        end
      end)
    end

    local function dotnet_launch_config()
      return setmetatable({
        type = 'coreclr',
        name = 'Launch selected project',
        request = 'launch',
      }, {
        __call = function()
          local dap_run_co = coroutine.running()

          dotnet.select_project({ prompt = 'Debug .NET: select project', kind = 'runnable' }, function(project)
            if not project then
              resume_dap_config(dap_run_co, { type = 'coreclr', name = 'Launch selected project', request = 'launch', program = dap.ABORT })
              return
            end

            dotnet.select_launch_profile(project, { prompt = 'Debug .NET: select launch profile' }, function(profile)
              build_dotnet_project(project, function(ok)
                local name = 'Launch selected project'
                local profile_label = dotnet.profile_label(profile)
                if profile_label then
                  name = name .. ' [' .. profile_label .. ']'
                end

                resume_dap_config(dap_run_co, {
                  type = 'coreclr',
                  name = name,
                  request = 'launch',
                  program = ok and find_project_dll(project) or dap.ABORT,
                  cwd = dotnet.profile_working_directory(project, profile),
                  args = dotnet.profile_args(profile),
                  console = 'integratedTerminal',
                  env = dotnet.profile_env(profile),
                })
              end)
            end)
          end)

          return coroutine.yield()
        end,
      })
    end

    dap.configurations.cs = {
      dotnet_launch_config(),
      {
        type = 'coreclr',
        name = 'Attach',
        request = 'attach',
        processId = require('dap.utils').pick_process,
      },
    }

    -- Install golang specific config
    require('dap-go').setup {
      delve = {
        -- On Windows delve must be run attached or it crashes.
        -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
