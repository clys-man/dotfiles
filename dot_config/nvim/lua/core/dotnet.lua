local M = {}

local ignored_dir_names = {
  '.git',
  '.idea',
  '.vs',
  '.vscode',
  'bin',
  'node_modules',
  'obj',
  'packages',
}

local ignored_dirs = {
  ['.git'] = true,
  ['.idea'] = true,
  ['.vs'] = true,
  ['.vscode'] = true,
  bin = true,
  node_modules = true,
  obj = true,
  packages = true,
}

local project_cache = {}
local project_info_cache = {}
local launch_profile_cache = {}

local default_env = {
  ASPNETCORE_ENVIRONMENT = 'Development',
  DOTNET_ENVIRONMENT = 'Development',
}

local function escape_pattern(value)
  return value:gsub('([^%w])', '%%%1')
end

local function read_project_content(project)
  local cached = project_info_cache[project]
  if cached then
    return cached.content
  end

  local ok, lines = pcall(vim.fn.readfile, project)
  local content = ok and table.concat(lines, '\n') or ''
  project_info_cache[project] = { content = content }

  return content
end

local function project_property(content, name)
  return content:match('<' .. name .. '>%s*(.-)%s*</' .. name .. '>')
end

local function has_xml_attribute_value(content, element, attribute, value)
  local pattern = '<' .. element .. '%s+[^>]-' .. attribute .. '%s*=%s*["\']' .. escape_pattern(value) .. '["\']'
  return content:match(pattern) ~= nil
end

local function has_sdk(content, sdk)
  local escaped_sdk = escape_pattern(sdk)

  return content:match('<Project%s+[^>]-Sdk%s*=%s*["\'][^"\']*' .. escaped_sdk .. '[^"\']*["\']') ~= nil
    or content:match('<Sdk%s+[^>]-Name%s*=%s*["\']' .. escaped_sdk .. '["\']') ~= nil
end

local function has_launch_settings(project)
  return vim.uv.fs_stat(vim.fs.joinpath(vim.fs.dirname(project), 'Properties', 'launchSettings.json')) ~= nil
end

local function launch_settings_path(project)
  return vim.fs.joinpath(vim.fs.dirname(project), 'Properties', 'launchSettings.json')
end

local function user_secrets_base_dir()
  if vim.fn.has 'win32' == 1 and vim.env.APPDATA and vim.env.APPDATA ~= '' then
    return vim.fs.joinpath(vim.env.APPDATA, 'Microsoft', 'UserSecrets')
  end

  return vim.fs.joinpath(vim.fn.expand '~', '.microsoft', 'usersecrets')
end

local function normalize_working_directory(project, working_directory)
  if type(working_directory) ~= 'string' or working_directory == '' then
    return nil
  end

  if working_directory:match '^/' or working_directory:match '^%a:[/\\]' then
    return vim.fs.normalize(working_directory)
  end

  return vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(project), working_directory))
end

local function split_command_line(value)
  if type(value) ~= 'string' or vim.trim(value) == '' then
    return {}
  end

  local args = {}
  local current = {}
  local quote = nil
  local escaped = false

  local function push_current()
    if #current > 0 then
      args[#args + 1] = table.concat(current)
      current = {}
    end
  end

  for index = 1, #value do
    local char = value:sub(index, index)

    if escaped then
      current[#current + 1] = char
      escaped = false
    elseif char == '\\' then
      escaped = true
    elseif quote then
      if char == quote then
        quote = nil
      else
        current[#current + 1] = char
      end
    elseif char == '"' or char == "'" then
      quote = char
    elseif char:match '%s' then
      push_current()
    else
      current[#current + 1] = char
    end
  end

  if escaped then
    current[#current + 1] = '\\'
  end

  push_current()
  return args
end

local function parse_launch_profiles(project)
  local cached = launch_profile_cache[project]
  if cached then
    return cached
  end

  local path = launch_settings_path(project)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    launch_profile_cache[project] = {}
    return launch_profile_cache[project]
  end

  local decode_ok, launch_settings = pcall(vim.json.decode, table.concat(lines, '\n'))
  if not decode_ok or type(launch_settings) ~= 'table' or type(launch_settings.profiles) ~= 'table' then
    vim.notify('Failed to parse ' .. path, vim.log.levels.WARN)
    launch_profile_cache[project] = {}
    return launch_profile_cache[project]
  end

  local profiles = {}
  for name, profile in pairs(launch_settings.profiles) do
    if type(profile) == 'table' and profile.commandName == 'Project' then
      profiles[#profiles + 1] = {
        name = name,
        command_name = profile.commandName,
        command_line_args = profile.commandLineArgs,
        application_url = profile.applicationUrl,
        environment_variables = type(profile.environmentVariables) == 'table' and profile.environmentVariables or {},
        launch_browser = profile.launchBrowser,
        launch_url = profile.launchUrl,
        working_directory = normalize_working_directory(project, profile.workingDirectory),
      }
    end
  end

  table.sort(profiles, function(left, right)
    return left.name < right.name
  end)

  launch_profile_cache[project] = profiles
  return profiles
end

local function filter_projects(projects, kind)
  if not kind or kind == 'all' then
    return projects
  end

  local filtered = {}
  for _, project in ipairs(projects) do
    if kind == 'runnable' and M.is_runnable_project(project) then
      filtered[#filtered + 1] = project
    elseif kind == 'test' and M.is_test_project(project) then
      filtered[#filtered + 1] = project
    elseif kind == 'user_secrets' and M.has_user_secrets(project) then
      filtered[#filtered + 1] = project
    end
  end

  return filtered
end

local function clear_project_info_cache(root)
  local normalized_root = vim.fs.normalize(root):gsub('/$', '')

  for project in pairs(project_info_cache) do
    local normalized_project = vim.fs.normalize(project)
    if normalized_project:sub(1, #normalized_root + 1) == normalized_root .. '/' then
      project_info_cache[project] = nil
    end
  end
end

local function clear_launch_profile_cache(root)
  local normalized_root = vim.fs.normalize(root):gsub('/$', '')

  for project in pairs(launch_profile_cache) do
    local normalized_project = vim.fs.normalize(project)
    if normalized_project:sub(1, #normalized_root + 1) == normalized_root .. '/' then
      launch_profile_cache[project] = nil
    end
  end
end

local function current_dir()
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name ~= '' then
    return vim.fs.dirname(buf_name)
  end

  return vim.fn.getcwd()
end

local function is_ignored_project(root, project)
  local relative = vim.fs.relpath(root, project) or project
  relative = relative:gsub('\\', '/')

  for part in relative:gmatch '[^/]+' do
    if ignored_dirs[part] then
      return true
    end
  end

  return false
end

local function normalize_project_path(root, project)
  project = vim.trim(project):gsub('^%./', '')
  if project:match '^/' or project:match '^%a:[/\\]' then
    return vim.fs.normalize(project)
  end

  return vim.fs.normalize(vim.fs.joinpath(root, project))
end

local function parse_project_output(root, output)
  local projects = {}

  for project in (output or ''):gmatch '[^\r\n]+' do
    local normalized = normalize_project_path(root, project)
    if not is_ignored_project(root, normalized) then
      projects[#projects + 1] = normalized
    end
  end

  table.sort(projects)
  return projects
end

local function cache_projects(root, projects)
  project_cache[root] = projects
  return vim.deepcopy(projects)
end

local function project_search_command()
  if vim.fn.executable 'rg' == 1 then
    local command = { 'rg', '--files', '--glob', '*.csproj' }

    for _, dir in ipairs(ignored_dir_names) do
      command[#command + 1] = '--glob'
      command[#command + 1] = '!' .. dir .. '/**'
      command[#command + 1] = '--glob'
      command[#command + 1] = '!**/' .. dir .. '/**'
    end

    return command, 'rg'
  end

  if vim.fn.executable 'fd' == 1 then
    local command = { 'fd', '--type', 'file', '--extension', 'csproj' }

    for _, dir in ipairs(ignored_dir_names) do
      command[#command + 1] = '--exclude'
      command[#command + 1] = dir
    end

    return command, 'fd'
  end

  if vim.fn.executable 'find' == 1 then
    local command = { 'find', '.' }

    command[#command + 1] = '('
    for index, dir in ipairs(ignored_dir_names) do
      if index > 1 then
        command[#command + 1] = '-o'
      end

      command[#command + 1] = '-name'
      command[#command + 1] = dir
    end
    command[#command + 1] = ')'
    command[#command + 1] = '-type'
    command[#command + 1] = 'd'
    command[#command + 1] = '-prune'
    command[#command + 1] = '-o'
    command[#command + 1] = '-type'
    command[#command + 1] = 'f'
    command[#command + 1] = '-name'
    command[#command + 1] = '*.csproj'
    command[#command + 1] = '-print'

    return command, 'find'
  end
end

function M.root()
  local start = current_dir()

  local git_dir = vim.fs.find('.git', { path = start, upward = true })[1]
  if git_dir then
    return vim.fs.dirname(git_dir)
  end

  local solution = vim.fs.find(function(name)
    return name:match '%.slnx?$' ~= nil
  end, { path = start, upward = true })[1]
  if solution then
    return vim.fs.dirname(solution)
  end

  return vim.fn.getcwd()
end

function M.projects(root)
  root = root or M.root()
  if project_cache[root] then
    return vim.deepcopy(project_cache[root])
  end

  local command = project_search_command()
  if command and vim.system then
    local result = vim.system(command, { cwd = root, text = true }):wait()
    if result.code == 0 or result.code == 1 then
      return cache_projects(root, parse_project_output(root, result.stdout))
    end
  end

  local projects = vim.fn.globpath(root, '**/*.csproj', false, true)
  local filtered = {}

  for _, project in ipairs(projects) do
    if not is_ignored_project(root, project) then
      filtered[#filtered + 1] = project
    end
  end

  table.sort(filtered)
  return cache_projects(root, filtered)
end

function M.projects_async(root, on_done)
  if type(root) == 'function' then
    on_done = root
    root = nil
  end

  root = root or M.root()
  if project_cache[root] then
    return vim.schedule(function()
      on_done(vim.deepcopy(project_cache[root]), root)
    end)
  end

  local command, executable = project_search_command()
  if not command or not vim.system then
    return vim.schedule(function()
      on_done(M.projects(root), root)
    end)
  end

  vim.system(command, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 and result.code ~= 1 then
        local error_message = vim.trim(result.stderr or '')
        vim.notify('Failed to list .NET projects with ' .. executable .. (error_message ~= '' and ': ' .. error_message or ''), vim.log.levels.ERROR)
        return on_done({}, root)
      end

      on_done(cache_projects(root, parse_project_output(root, result.stdout)), root)
    end)
  end)
end

function M.clear_cache(root)
  root = root or M.root()
  project_cache[root] = nil
  clear_project_info_cache(root)
  clear_launch_profile_cache(root)
end

local function project_info(project)
  local cached = project_info_cache[project]
  if cached and cached.kind then
    return cached
  end

  local content = read_project_content(project)
  cached = project_info_cache[project]

  local output_type = project_property(content, 'OutputType')
  local user_secrets_id = project_property(content, 'UserSecretsId')
  local launch_settings = has_launch_settings(project)
  local is_test = ((project_property(content, 'IsTestProject') or ''):lower() == 'true')
    or has_xml_attribute_value(content, 'PackageReference', 'Include', 'Microsoft.NET.Test.Sdk')
  local is_runnable = not is_test
    and (has_sdk(content, 'Microsoft.NET.Sdk.Web') or has_sdk(content, 'Microsoft.NET.Sdk.Worker') or (output_type and output_type:lower() == 'exe'))

  cached.output_type = output_type
  cached.has_launch_settings = launch_settings
  cached.is_test = is_test
  cached.is_runnable = is_runnable
  cached.kind = is_test and 'test' or (is_runnable and 'runnable' or 'library')
  cached.user_secrets_id = user_secrets_id

  return cached
end

function M.project_info(project)
  local info = project_info(project)
  return {
    has_launch_settings = info.has_launch_settings,
    is_runnable = info.is_runnable,
    is_test = info.is_test,
    kind = info.kind,
    output_type = info.output_type,
    user_secrets_id = info.user_secrets_id,
  }
end

function M.is_runnable_project(project)
  return project_info(project).is_runnable
end

function M.is_test_project(project)
  return project_info(project).is_test
end

function M.user_secrets_id(project)
  local value = project_info(project).user_secrets_id
  return value and value ~= '' and value or nil
end

function M.has_user_secrets(project)
  return M.user_secrets_id(project) ~= nil
end

function M.user_secrets_path(project)
  local user_secrets_id = M.user_secrets_id(project)
  if not user_secrets_id then
    return nil
  end

  return vim.fs.joinpath(user_secrets_base_dir(), user_secrets_id, 'secrets.json')
end

function M.edit_user_secrets()
  M.select_project({ prompt = '.NET User Secrets: select project', kind = 'user_secrets', always_select = true }, function(project, root)
    if not project then
      return
    end

    local secrets_path = M.user_secrets_path(project)
    if not secrets_path then
      local label = M.project_label(root, project)
      vim.notify('No UserSecretsId found in ' .. label .. '. Run: dotnet user-secrets init --project ' .. vim.fn.shellescape(project), vim.log.levels.WARN)
      return
    end

    local secrets_dir = vim.fs.dirname(secrets_path)
    local mkdir_ok = pcall(vim.fn.mkdir, secrets_dir, 'p')
    if not mkdir_ok or not vim.uv.fs_stat(secrets_dir) then
      vim.notify('Failed to create user secrets directory: ' .. secrets_dir, vim.log.levels.ERROR)
      return
    end

    if not vim.uv.fs_stat(secrets_path) then
      local write_ok, result = pcall(vim.fn.writefile, { '{', '}' }, secrets_path)
      if not write_ok or result ~= 0 then
        vim.notify('Failed to create user secrets file: ' .. secrets_path, vim.log.levels.ERROR)
        return
      end
    end

    local edit_ok, edit_error = pcall(vim.cmd.edit, vim.fn.fnameescape(secrets_path))
    if not edit_ok then
      vim.notify('Failed to open user secrets file: ' .. tostring(edit_error), vim.log.levels.ERROR)
      return
    end

    vim.bo.filetype = 'json'
    vim.notify('Editing user secrets for ' .. M.project_label(root, project), vim.log.levels.INFO)
  end)
end

function M.select_project(opts, on_choice)
  if type(opts) == 'function' then
    on_choice = opts
    opts = {}
  end

  opts = opts or {}
  local root = opts.root or M.root()

  M.projects_async(root, function(projects)
    projects = filter_projects(projects, opts.kind)

    if #projects == 0 then
      local kind_label = ({ runnable = 'runnable .NET project', test = '.NET test project', user_secrets = '.NET project with UserSecretsId' })[opts.kind]
        or '.NET project'
      local message = 'No ' .. kind_label .. ' found under ' .. root
      if opts.kind == 'user_secrets' then
        message = message .. '. Run dotnet user-secrets init --project <project> first.'
      end

      vim.notify(message, vim.log.levels.WARN)
      return on_choice(nil, root)
    end

    if #projects == 1 and not opts.always_select then
      return on_choice(projects[1], root)
    end

    vim.ui.select(projects, {
      prompt = opts.prompt or 'Select .NET project',
      format_item = function(project)
        return vim.fs.relpath(root, project) or vim.fn.fnamemodify(project, ':~:.')
      end,
    }, function(project)
      on_choice(project, root)
    end)
  end)
end

function M.launch_profiles(project)
  return vim.deepcopy(parse_launch_profiles(project))
end

function M.select_launch_profile(project, opts, on_choice)
  if type(opts) == 'function' then
    on_choice = opts
    opts = {}
  end

  opts = opts or {}
  local profiles = parse_launch_profiles(project)
  if #profiles == 0 then
    return on_choice(nil)
  end

  if #profiles == 1 and not opts.always_select then
    return on_choice(vim.deepcopy(profiles[1]))
  end

  vim.ui.select(profiles, {
    prompt = opts.prompt or 'Select .NET launch profile',
    format_item = function(profile)
      local label = profile.name
      if profile.application_url then
        label = label .. ' - ' .. profile.application_url
      end

      return label
    end,
  }, function(profile)
    on_choice(profile and vim.deepcopy(profile) or nil)
  end)
end

function M.profile_args(profile)
  return profile and split_command_line(profile.command_line_args) or {}
end

function M.profile_env(profile, env)
  local merged = vim.tbl_extend('force', {}, env or default_env)
  if not profile then
    return merged
  end

  for key, value in pairs(profile.environment_variables or {}) do
    merged[key] = tostring(value)
  end

  if profile.application_url and not merged.ASPNETCORE_URLS then
    merged.ASPNETCORE_URLS = profile.application_url
  end

  return merged
end

function M.profile_working_directory(project, profile)
  return profile and profile.working_directory or vim.fs.dirname(project)
end

function M.project_label(root, project)
  return vim.fs.relpath(root, project) or vim.fn.fnamemodify(project, ':~:.')
end

function M.profile_label(profile)
  return profile and profile.name or nil
end

local dotnet_tasks = {
  build = {
    label = 'Build',
    kind = 'all',
    prompt = '.NET Build: select project',
    args = function(project)
      return { 'build', project }
    end,
  },
  run = {
    label = 'Run',
    kind = 'runnable',
    prompt = '.NET Run: select project',
    launch_profile = true,
    args = function(project, profile)
      local args = { 'run', '--project', project }
      if profile then
        vim.list_extend(args, { '--launch-profile', profile.name })
      end

      return args
    end,
    unique_active = true,
  },
  test = {
    label = 'Test',
    kind = 'test',
    prompt = '.NET Test: select project',
    args = function(project)
      return { 'test', project }
    end,
  },
  watch = {
    label = 'Watch',
    kind = 'runnable',
    prompt = '.NET Watch: select project',
    launch_profile = true,
    args = function(project, profile)
      local args = { 'watch', '--project', project, 'run' }
      if profile then
        vim.list_extend(args, { '--launch-profile', profile.name })
      end

      return args
    end,
    unique_active = true,
  },
}

local dotnet_task_components = {
  'on_exit_set_status',
  'on_complete_notify',
}

local function require_overseer()
  local ok, overseer = pcall(require, 'overseer')
  if ok then
    return overseer
  end

  vim.notify('overseer.nvim is not available. Run :Lazy sync to install it.', vim.log.levels.ERROR)
end

local function is_active_task(task)
  return (type(task.is_running) == 'function' and task:is_running()) or (type(task.is_pending) == 'function' and task:is_pending())
end

local function find_active_dotnet_task(overseer, action, root, project, profile)
  local profile_name = M.profile_label(profile) or ''

  for _, task in ipairs(overseer.list_tasks {}) do
    local metadata = task.metadata or {}
    if
      metadata.dotnet_action == action
      and metadata.dotnet_root == root
      and metadata.dotnet_project == project
      and (metadata.dotnet_profile or '') == profile_name
      and is_active_task(task)
    then
      return task
    end
  end
end

local function select_task_profile(spec, project, on_choice)
  if not spec.launch_profile then
    return on_choice(nil)
  end

  M.select_launch_profile(project, { prompt = '.NET ' .. spec.label .. ': select launch profile' }, on_choice)
end

function M.run_overseer_task(action)
  local spec = dotnet_tasks[action]
  if not spec then
    vim.notify('Unknown .NET task: ' .. tostring(action), vim.log.levels.ERROR)
    return
  end

  M.select_project({ prompt = spec.prompt, kind = spec.kind }, function(project, root)
    if not project then
      return
    end

    select_task_profile(spec, project, function(profile)
      local overseer = require_overseer()
      if not overseer then
        return
      end

      local label = M.project_label(root, project)
      local profile_label = M.profile_label(profile)
      if profile_label then
        label = label .. ' [' .. profile_label .. ']'
      end

      local existing = spec.unique_active and find_active_dotnet_task(overseer, action, root, project, profile)
      if existing then
        overseer.open { enter = false, direction = 'bottom', focus_task_id = existing.id }
        vim.notify('Task already running: ' .. existing.name, vim.log.levels.INFO)
        return existing
      end

      local task = overseer.new_task {
        name = '.NET ' .. spec.label .. ': ' .. label,
        cmd = 'dotnet',
        args = spec.args(project, profile),
        cwd = (profile and M.profile_working_directory(project, profile)) or root,
        env = M.profile_env(profile),
        metadata = {
          dotnet_action = action,
          dotnet_profile = profile_label or '',
          dotnet_project = project,
          dotnet_root = root,
        },
        components = dotnet_task_components,
      }

      task:start()
      overseer.open { enter = false, direction = 'bottom', focus_task_id = task.id }
      return task
    end)
  end)
end

return M
