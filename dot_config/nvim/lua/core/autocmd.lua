local is_building = false
local build_pending = false
local current_cmd = ''
local current_job_id = nil
local force_stopped = false

vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    pcall(vim.treesitter.start)
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = '*.tex',
  callback = function()
    if is_building then
      build_pending = true
      vim.notify('Build in progress. Changes queued...', vim.log.levels.INFO)
      return
    end

    local current_file = vim.api.nvim_buf_get_name(0)

    local match = vim.fs.find({ '.nvim_latex_build.json', '.git', 'Makefile' }, {
      upward = true,
      stop = vim.loop.os_homedir(),
      path = vim.fs.dirname(current_file),
    })

    local root_dir = #match > 0 and vim.fs.dirname(match[1]) or vim.fs.dirname(current_file)
    local config_file = root_dir .. '/.nvim_latex_build.json'

    local function run_command(cmd)
      is_building = true
      force_stopped = false
      current_cmd = cmd
      vim.notify('Compiling LaTeX...', vim.log.levels.INFO)
      local output = {}

      local function capture_output(_, data)
        if data then
          for _, line in ipairs(data) do
            table.insert(output, line)
          end
        end
      end

      current_job_id = vim.fn.jobstart({ 'sh', '-c', cmd }, {
        cwd = root_dir,
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = capture_output,
        on_stderr = capture_output,
        on_exit = function(_, exit_code)
          is_building = false
          current_job_id = nil

          if force_stopped then
            force_stopped = false
            return
          end

          if exit_code == 0 then
            vim.notify('PDF updated successfully!', vim.log.levels.INFO)
          else
            vim.notify('Compilation error. Check the output window.', vim.log.levels.ERROR)
            vim.schedule(function()
              local buf = vim.api.nvim_create_buf(false, true)
              vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
              vim.api.nvim_command 'botright 15split'
              vim.api.nvim_win_set_buf(0, buf)
              vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
            end)
          end

          if build_pending then
            build_pending = false
            vim.schedule(function()
              run_command(current_cmd)
            end)
          end
        end,
      })
    end

    local function save_and_run(main_file, cmd)
      local data = vim.fn.json_encode { main_file = main_file, command = cmd }
      local fw = io.open(config_file, 'w')
      if fw then
        fw:write(data)
        fw:close()
      end
      run_command(cmd)
    end

    local function prompt_config()
      vim.ui.input({
        prompt = 'Main file path: ',
        default = current_file,
      }, function(file_input)
        if not file_input or file_input == '' then
          vim.notify('Compilation canceled.', vim.log.levels.WARN)
          return
        end

        if not file_input:match '%.tex$' then
          vim.notify('Invalid format. The file must end with .tex', vim.log.levels.ERROR)
          prompt_config()
          return
        end

        local relative_path = file_input
        if string.sub(file_input, 1, #root_dir) == root_dir then
          relative_path = string.sub(file_input, #root_dir + 2)
        end

        local default_cmd = 'latexmk -pdf ' .. relative_path

        vim.ui.input({
          prompt = 'Compilation command: ',
          default = default_cmd,
        }, function(cmd_input)
          if not cmd_input or cmd_input == '' then
            vim.notify('Compilation canceled.', vim.log.levels.WARN)
            return
          end
          save_and_run(file_input, cmd_input)
        end)
      end)
    end

    local f = io.open(config_file, 'r')
    if f then
      local content = f:read '*a'
      f:close()

      local ok, config = pcall(vim.fn.json_decode, content)

      if ok and type(config) == 'table' and config.main_file and config.command then
        if config.main_file:match '%.tex$' then
          run_command(config.command)
        else
          vim.notify('Invalid main_file in config. Reconfiguring...', vim.log.levels.ERROR)
          prompt_config()
        end
      else
        vim.notify('Invalid config format. Reconfiguring...', vim.log.levels.ERROR)
        prompt_config()
      end
    else
      prompt_config()
    end
  end,
})

vim.api.nvim_create_user_command('LatexBuildStop', function()
  if current_job_id then
    force_stopped = true
    vim.fn.jobstop(current_job_id)
    vim.notify('LaTeX compilation stopped forcefully.', vim.log.levels.WARN)
  else
    vim.notify('No LaTeX compilation is currently running.', vim.log.levels.INFO)
  end

  is_building = false
  build_pending = false
  current_job_id = nil
end, { desc = 'Stops the running LaTeX compilation and clears the queue' })
