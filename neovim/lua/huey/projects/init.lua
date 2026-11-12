local M = {}

-- A stable, per-user socket directory shared by every nvim process (the TUI
-- and all headless project servers). It MUST be identical across processes
-- so they can discover each other's sockets via probe().
--
-- On Linux, stdpath("run") is $XDG_RUNTIME_DIR/nvim.user and is stable. On
-- macOS, XDG_RUNTIME_DIR is unset and stdpath("run") falls back to a temp dir
-- that is *unique per process* -- so each process would look in a different
-- place, never reuse a server, and keep spawning competing duplicates. Use a
-- stable TMPDIR-based path there instead.
--
-- On Windows, nvim can only listen on named pipes, so the "directory" is a
-- pipe-name prefix. Pipe names may contain '/', so `<dir>/<name>.sock` works.
local is_win = vim.fn.has('win32') == 1
local function default_server_dir()
  if is_win then
    return [[\\.\pipe\nvim-projects-]] .. (vim.env.USERNAME or 'user')
  end
  if vim.env.XDG_RUNTIME_DIR and vim.env.XDG_RUNTIME_DIR ~= '' then
    return vim.fn.stdpath('run') .. '/projects'
  end
  local tmp = (vim.env.TMPDIR or '/tmp'):gsub('/+$', '')
  return tmp .. '/nvim-projects-' .. (vim.env.USER or vim.env.LOGNAME or 'user')
end

local defaults = {
  -- JSON list of { name = string, path = string }; `<Leader>wa` appends to it
  store = vim.fn.stdpath('data') .. '/projects.json',
  -- Always listed first, whatever the store holds
  pinned = { { name = 'nvim', path = vim.fs.joinpath(vim.uv.os_homedir(), 'nvim') } },
  server_dir = default_server_dir(),
  -- New jj workspaces go in `<workspace_dir>/<project>/<workspace>`, outside
  -- the repo, so they never show up in its own file listings
  workspace_dir = vim.fn.stdpath('data') .. '/workspaces',
  -- What `M.add_agent()` runs, with the prompt appended as the last argument
  agent_cmd = { 'claude' },
}

local opts = defaults

-- Each jj workspace of a project gets its own server, at
-- `<server_dir>/<project>/<workspace>.sock`. The project's own folder is the
-- `default` workspace, jj repo or not.
local function sock_for(name, ws)
  return opts.server_dir .. '/' .. name .. '/' .. (ws or 'default') .. '.sock'
end

--- How a server is shown and typed: the project name for its default
--- workspace, `<project>/<workspace>` otherwise.
--- @param name string
--- @param ws string?
--- @return string
function M.label(name, ws)
  if not ws or ws == 'default' then return name end
  return name .. '/' .. ws
end

-- Splits a label back into project and workspace.
local function parse_label(label)
  local name, ws = label:match('^([^/]+)/(.+)$')
  if name then return name, ws end
  return label, 'default'
end

local function same_path(a, b) return vim.fn.resolve(a) == vim.fn.resolve(b) end

-- The store is re-read only when the file changes. Every server reads it, so a
-- project added in one shows up in the others.
local cache = {}

local function read_store()
  local stat = vim.uv.fs_stat(opts.store)
  if not stat then return {} end
  local key = ('%d:%d:%d'):format(stat.mtime.sec, stat.mtime.nsec, stat.size)
  if cache.key == key then return cache.list end
  local ok, decoded =
    pcall(vim.json.decode, table.concat(vim.fn.readfile(opts.store), '\n'))
  if not ok or type(decoded) ~= 'table' then
    vim.notify('projects: failed to decode ' .. opts.store, vim.log.levels.WARN)
    decoded = {}
  end
  cache.key, cache.list = key, decoded
  return decoded
end

local function write_store(list)
  vim.fn.mkdir(vim.fs.dirname(opts.store), 'p')
  local json = vim.json.encode(list, { indent = '  ' })
  vim.fn.writefile(vim.split(json, '\n'), opts.store)
  cache = {}
end

--- Pinned projects, then stored ones, skipping any path already listed.
--- @return { name: string, path: string }[]
local function list()
  local out = {}
  local add = function(p)
    local path = vim.fs.normalize(p.path)
    for _, o in ipairs(out) do
      if same_path(o.path, path) then return end
    end
    out[#out + 1] = { name = p.name, path = path }
  end
  vim.iter(opts.pinned):each(add)
  vim.iter(read_store()):each(add)
  return out
end

local function find(name)
  for _, p in ipairs(list()) do
    if p.name == name then return p end
  end
end

-- A named pipe can't be stat'ed, so on Windows only connecting tells.
local function may_exist(sock) return is_win or vim.loop.fs_stat(sock) ~= nil end

local function probe(sock)
  if not may_exist(sock) then return false end
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
  if not ok or chan == 0 then return false end
  pcall(vim.fn.chanclose, chan)
  return true
end

-- Run a Lua chunk in the server at `sock` and return its result, or nil when
-- the server is unreachable or the chunk errors.
local function rpc_lua(sock, code, args)
  if not may_exist(sock) then return nil end
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
  if not ok or chan == 0 then return nil end
  local got, res = pcall(vim.rpcrequest, chan, 'nvim_exec_lua', code, args or {})
  pcall(vim.fn.chanclose, chan)
  if got and res ~= vim.NIL then return res end
end

-- True when `sock` is one of this process's own listen addresses.
local function is_self(sock) return vim.tbl_contains(vim.fn.serverlist(), sock) end

--- Project and workspace this process serves, or nil when it is no project
--- server (the TUI's own nvim).
--- @return string? name, string? ws
local function self_server()
  local prefix = opts.server_dir .. '/'
  for _, addr in ipairs(vim.fn.serverlist()) do
    if addr:sub(1, #prefix) == prefix then
      local name, ws = addr:sub(#prefix + 1):match('^([^/]+)/([^/]+)%.sock$')
      if name and find(name) then return name, ws end
    end
  end
end

-- `default` first, then by name, the order `jj workspace list` gives
local function ws_before(a, b)
  if a == 'default' or b == 'default' then return a == 'default' and b ~= a end
  return a < b
end

--- Workspaces of project `name` whose server is running, `default` first.
--- @param name string
--- @return string[]
local function running_workspaces(name)
  local candidates
  if is_win then
    -- named pipes can't be listed by folder, so ask jj what there could be
    candidates = vim.tbl_map(
      function(w) return w.name end,
      M.workspaces(name) or { { name = 'default' } }
    )
  else
    candidates = {}
    local dir = opts.server_dir .. '/' .. name
    for _, f in ipairs(vim.fn.isdirectory(dir) == 1 and vim.fn.readdir(dir) or {}) do
      local ws = f:match('^(.+)%.sock$')
      if ws then candidates[#candidates + 1] = ws end
    end
  end
  local out = vim.tbl_filter(
    function(ws) return probe(sock_for(name, ws)) end,
    candidates
  )
  table.sort(out, ws_before)
  return out
end

--- 'running' when the server of workspace `ws` of project `name` is up. With
--- no `ws`, when any of the project's servers is.
--- @param name string
--- @param ws string?
--- @return 'running'|'stopped'
function M.status(name, ws)
  local up
  if ws then
    up = probe(sock_for(name, ws))
  else
    up = #running_workspaces(name) > 0
  end
  return up and 'running' or 'stopped'
end

--- Every running server, in configuration order and then workspace order.
--- @return { project: string, workspace: string }[]
function M.servers()
  local out = {}
  for _, p in ipairs(list()) do
    for _, ws in ipairs(running_workspaces(p.name)) do
      out[#out + 1] = { project = p.name, workspace = ws }
    end
  end
  return out
end

local function spawn(sock, path)
  if not is_win then
    -- macOS caps a socket path at 104 bytes; nvim would fail to listen
    if #sock > 103 then
      vim.notify(
        ('projects: socket path is too long: %s'):format(sock),
        vim.log.levels.ERROR
      )
      return false
    end
    vim.fn.mkdir(vim.fs.dirname(sock), 'p')
  end
  -- progpath, not 'nvim': run the same nvim binary as this one
  vim.fn.jobstart({
    vim.v.progpath ~= '' and vim.v.progpath or 'nvim',
    '--listen',
    sock,
    '--headless',
    '--cmd',
    'cd ' .. vim.fn.fnameescape(path),
    -- A headless server has no terminal to ask for its background color, so
    -- it would default to dark. Copy this one's, which came from the terminal.
    '--cmd',
    'set background=' .. vim.o.background,
  }, { detach = true })
  if not vim.wait(2000, function() return probe(sock) end, 50) then
    vim.notify(
      ('projects: timed out waiting for %s'):format(sock),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

--- Address of the server of workspace `ws` (default `default`) of project
--- `name`, starting it when it isn't running. Nil when the project or
--- workspace is unknown or the server didn't come up.
--- @param name string
--- @param ws string?
--- @return string?
function M.ensure(name, ws)
  ws = ws or 'default'
  local project = find(name)
  if not project then
    vim.notify(("projects: unknown name '%s'"):format(name), vim.log.levels.ERROR)
    return
  end
  local addr = sock_for(name, ws)
  if probe(addr) then return addr end

  local path = project.path
  if ws ~= 'default' then
    local found = vim
      .iter(M.workspaces(name) or {})
      :find(function(w) return w.name == ws end)
    if not found then
      vim.notify(
        ("projects: %s has no workspace '%s'"):format(name, ws),
        vim.log.levels.ERROR
      )
      return
    end
    path = found.path
  end
  if not spawn(addr, path) then return end
  return addr
end

--- Connect the UI to the server of workspace `ws` (default `default`) of
--- project `name`, starting it if needed.
--- @param name string
--- @param ws string?
--- @param stop_current boolean? use `:connect!`, stopping the server left behind
function M.connect(name, ws, stop_current)
  local addr = M.ensure(name, ws)
  if not addr then return end
  vim.cmd((stop_current and 'connect! ' or 'connect ') .. vim.fn.fnameescape(addr))
end

local function stop_one(sock)
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
  if not ok or chan == 0 then return end
  pcall(vim.rpcnotify, chan, 'nvim_command', 'qa!')
  pcall(vim.fn.chanclose, chan)
  vim.wait(1000, function() return not probe(sock) end, 50)
  if not is_win then pcall(os.remove, sock) end
end

--- Stop the server of workspace `ws` of project `name`, or every server of
--- the project when `ws` is nil.
--- @param name string
--- @param ws string?
function M.stop(name, ws)
  local all = ws and { ws } or running_workspaces(name)
  local socks =
    vim.tbl_filter(probe, vim.tbl_map(function(w) return sock_for(name, w) end, all))
  if #socks == 0 then
    vim.notify(
      ('projects: %s is not running'):format(M.label(name, ws)),
      vim.log.levels.WARN
    )
    return
  end
  vim.iter(socks):each(stop_one)
end

--- Every workspace of every project, in configuration order and then
--- workspace order. A project that is not a jj repo has only `default`.
--- @return { project: string, workspace: string, path: string }[]
function M.targets()
  local out = {}
  for _, p in ipairs(list()) do
    for _, w in
      ipairs(M.workspaces(p.name) or { { name = 'default', path = p.path } })
    do
      out[#out + 1] = { project = p.name, workspace = w.name, path = w.path }
    end
  end
  return out
end

--- Pick a workspace of any project, each with its own server.
function M.pick()
  local items = {}
  for _, t in ipairs(M.targets()) do
    local running = M.status(t.project, t.workspace) == 'running'
    items[#items + 1] = {
      project = t.project,
      workspace = t.workspace,
      text = ('%s  %-24s  %s'):format(
        running and '●' or '○',
        M.label(t.project, t.workspace),
        vim.fn.fnamemodify(t.path, ':~')
      ),
    }
  end
  MiniPick.start({
    source = {
      name = 'Projects',
      items = items,
      choose = function(item)
        if not item then return end
        vim.schedule(function() M.connect(item.project, item.workspace) end)
      end,
    },
  })
end

--- Add the folder at `path` to the stored projects, named after the folder. A
--- name already in use gets the parent folder prefixed, e.g. 'work-api'.
--- @param path string
--- @return string? name of the new or existing project
function M.add(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  for _, p in ipairs(list()) do
    if same_path(p.path, path) then
      vim.notify(("projects: '%s' is already a project"):format(p.name))
      return p.name
    end
  end

  local name = vim.fs.basename(path)
  if find(name) then name = vim.fs.basename(vim.fs.dirname(path)) .. '-' .. name end
  if find(name) then
    vim.notify(("projects: name '%s' is taken"):format(name), vim.log.levels.ERROR)
    return
  end

  local stored = vim.deepcopy(read_store())
  stored[#stored + 1] = { name = name, path = path }
  write_store(stored)
  vim.notify(("projects: added '%s'"):format(name))
  return name
end

--- Pick a folder under home and add it as a project. Hidden folders, Library
--- and anything gitignored are left out.
function M.pick_add()
  local home = vim.uv.os_homedir()
  MiniPick.builtin.cli({
    command = {
      'fd',
      '--type=directory',
      '--max-depth=4',
      '--exclude=Library',
      '--exclude=node_modules',
    },
    postprocess = function(lines)
      local items = {}
      for _, l in ipairs(lines) do
        if l ~= '' then
          local rel = l:gsub('/$', '')
          items[#items + 1] =
            { text = '~/' .. rel, path = vim.fs.joinpath(home, rel) }
        end
      end
      return items
    end,
    spawn_opts = { cwd = home },
  }, {
    source = {
      name = 'Add project',
      cwd = home,
      choose = function(item)
        if not item then return end
        vim.schedule(function() M.add(item.path) end)
      end,
    },
  })
end

--- Run a Lua chunk in every running server, in `M.servers()` order. This
--- server runs it in-process rather than over RPC.
--- @param code string Lua chunk; receives `args` as `...`
--- @param args any[]?
--- @return { project: string, workspace: string, result: any }[] nil results are skipped
function M.collect(code, args)
  args = args or {}
  local out = {}
  for _, s in ipairs(M.servers()) do
    local sock = sock_for(s.project, s.workspace)
    local res
    if is_self(sock) then
      res = assert(loadstring(code))(unpack(args))
    else
      res = rpc_lua(sock, code, args)
    end
    if res ~= nil then
      out[#out + 1] = { project = s.project, workspace = s.workspace, result = res }
    end
  end
  return out
end

--- Run a Lua chunk in the server of workspace `ws` of project `name`, in
--- process when that is this one. Nil when the server is unreachable or the
--- chunk errors.
--- @param name string
--- @param ws string
--- @param code string Lua chunk; receives `args` as `...`
--- @param args any[]?
--- @return any
local function run_in(name, ws, code, args)
  args = args or {}
  local sock = sock_for(name, ws)
  if not is_self(sock) then return rpc_lua(sock, code, args) end
  local ok, res = pcall(assert(loadstring(code)), unpack(args))
  if ok then return res end
end

-- Terminals with a tabline status icon (see 'huey/term.lua'), plus running ones
-- that reported a status before but have none now, shown as idle, and running
-- ones `M.add_agent()` started that have not reported yet.
local list_bots = [[
  local term = rawget(_G, 'HueyTerm')
  local out = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == 'terminal' then
      local prompt = vim.b[b].huey_prompt
      local running = vim.fn.jobwait({ vim.bo[b].channel }, 0)[1] == -1
      local icon = term and (term.get_icon(b) or (term.is_bot and term.is_bot(b) and '·'))
        or (prompt and running and '·')
      if icon then
        out[#out + 1] = {
          bufnr = b,
          name = vim.api.nvim_buf_get_name(b),
          icon = icon,
          title = vim.b[b].term_title,
          prompt = prompt,
        }
      end
    end
  end
  return out
]]

--- What a terminal's title says it is working on, or nil when it says nothing
--- useful. Claude Code titles are "<state glyph> <topic summary>"; the glyph
--- repeats the status icon, so it is dropped.
--- @param title string? `b:term_title`
--- @return string?
local function summary(title)
  if not title or title:match('^term://') then return nil end
  title = vim.trim((title:gsub('^[\128-\255]+%s+', '')))
  -- Claude Code's title before the first prompt
  if title == '' or title == 'Claude Code' then return nil end
  return title
end

--- Picker rows for every terminal with a status in a running server. Read
--- live from each server on every call; nothing is cached.
--- @return table[]
function M.bot_items()
  local items = {}
  for _, r in ipairs(M.collect(list_bots)) do
    for _, b in ipairs(r.result) do
      items[#items + 1] = {
        project = r.project,
        workspace = r.workspace,
        -- not `bufnr`: MiniPick would treat it as a buffer in this process
        remote_buf = b.bufnr,
        name = b.name,
        text = ('%s  %-12s %s'):format(
          b.icon,
          M.label(r.project, r.workspace),
          summary(b.title) or b.prompt or vim.fn.fnamemodify(b.name, ':~')
        ),
      }
    end
  end
  return items
end

local refresh_ms = 1000

--- Pick a terminal with a status from any running server. Rows refresh
--- while the picker is open so the icons track the terminals.
function M.pick_bots()
  local items = M.bot_items()
  local texts = function(list)
    return table.concat(vim.tbl_map(function(i) return i.text end, list), '\n')
  end
  local shown = texts(items)

  local timer = assert(vim.uv.new_timer())
  local stop = function()
    if timer:is_closing() then return end
    timer:stop()
    timer:close()
  end
  timer:start(
    refresh_ms,
    refresh_ms,
    vim.schedule_wrap(function()
      if not MiniPick.is_picker_active() then return stop() end
      local fresh = M.bot_items()
      -- only on change: setting items moves the cursor back to the top
      if texts(fresh) == shown then return end
      shown = texts(fresh)
      MiniPick.set_picker_items(fresh)
    end)
  )
  vim.api.nvim_create_autocmd('User', {
    pattern = 'MiniPickStop',
    once = true,
    callback = stop,
  })

  MiniPick.start({
    source = {
      name = 'Bots (projects)',
      items = items,
      preview = function(buf_id, item)
        local lines = M.agent_lines(item.project, item.workspace, item.remote_buf)
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        -- the latest output is the interesting part of a terminal
        local win = vim.fn.bufwinid(buf_id)
        if win ~= -1 then
          pcall(vim.api.nvim_win_set_cursor, win, { math.max(#lines, 1), 0 })
        end
      end,
      choose = function(item)
        if not item then return end
        vim.schedule(
          function() M.open_agent(item.project, item.workspace, item.remote_buf) end
        )
      end,
    },
  })
end

--- Agent terminals in the server of workspace `ws` of project `name`, as
--- `M.pick_bots()` lists them. Empty when the server is not running.
--- @param name string
--- @param ws string
--- @return { bufnr: integer, icon: string, text: string, prompt: string? }[]
function M.agents(name, ws)
  if not probe(sock_for(name, ws)) then return {} end
  return vim.tbl_map(
    function(b)
      return {
        bufnr = b.bufnr,
        icon = b.icon,
        text = summary(b.title) or b.prompt or vim.fn.fnamemodify(b.name, ':~'),
        prompt = b.prompt,
      }
    end,
    run_in(name, ws, list_bots) or {}
  )
end

-- Starts `cmd` in a new terminal buffer without showing it, so the UI on that
-- server stays where it is. The prompt is kept so the agent can be listed
-- before it reports a status.
local start_agent = [[
  local cmd, prompt = ...
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_call(buf, function() vim.fn.jobstart(cmd, { term = true }) end)
  vim.b[buf].huey_prompt = prompt
  return buf
]]

--- Starts an agent (`agent_cmd` with `prompt`) in a terminal of the server of
--- workspace `ws` of project `name`, starting the server if needed.
--- @param name string
--- @param ws string
--- @param prompt string
--- @return integer? bufnr of the terminal in that server
function M.add_agent(name, ws, prompt)
  if not M.ensure(name, ws) then return end
  local cmd = vim.list_extend(vim.deepcopy(opts.agent_cmd), { prompt })
  local buf = run_in(name, ws, start_agent, { cmd, prompt })
  if not buf then
    vim.notify(
      ('projects: failed to start an agent in %s'):format(M.label(name, ws)),
      vim.log.levels.ERROR
    )
  end
  return buf
end

--- Lines of terminal `bufnr` in the server of workspace `ws` of project
--- `name`, without the blank lines a terminal pads its end with.
--- @param name string
--- @param ws string
--- @param bufnr integer
--- @return string[]
function M.agent_lines(name, ws, bufnr)
  local lines = run_in(
    name,
    ws,
    'return vim.api.nvim_buf_get_lines(..., 0, -1, false)',
    { bufnr }
  ) or {}
  while #lines > 0 and lines[#lines] == '' do
    lines[#lines] = nil
  end
  return lines
end

--- Switches the server of workspace `ws` of project `name` to terminal
--- `bufnr`, then connects the UI to it when it is another server.
--- @param name string
--- @param ws string
--- @param bufnr integer
function M.open_agent(name, ws, bufnr)
  run_in(name, ws, 'vim.cmd.buffer(...)', { bufnr })
  if not is_self(sock_for(name, ws)) then M.connect(name, ws) end
end

-- Runs jj in `cwd`. Returns stdout, or nil and the error when it fails or
-- jj is not installed.
local function jj(cwd, args)
  local cmd = vim.list_extend({ 'jj', '--no-pager' }, args)
  local ok, out = pcall(
    function() return vim.system(cmd, { cwd = cwd, text = true }):wait() end
  )
  if not ok then return nil, out end
  if out.code ~= 0 then return nil, vim.trim(out.stderr) end
  return out.stdout
end

local function jj_failed(args, err)
  vim.notify(('projects: jj %s: %s'):format(args[1], err), vim.log.levels.ERROR)
end

--- jj workspaces of project `name`, the default one first. Nil when the
--- project is unknown or not a jj repo.
--- @param name string
--- @return { name: string, path: string }[]?
function M.workspaces(name)
  local project = find(name)
  if not project then return end
  -- quietly nil for a plain folder or git repo
  if not jj(project.path, { 'root' }) then return end
  -- --ignore-working-copy: listing should not snapshot the working copy
  local args = {
    'workspace',
    'list',
    '--ignore-working-copy',
    '-T',
    [[name ++ "\t" ++ self.root() ++ "\n"]],
  }
  local out, err = jj(project.path, args)
  if not out then return jj_failed(args, err) end
  local list = {}
  for line in vim.gsplit(out, '\n', { trimempty = true }) do
    local ws, path = line:match('^(.-)\t(.*)$')
    if ws then
      local entry = { name = ws, path = vim.fs.normalize(path) }
      table.insert(list, ws == 'default' and 1 or #list + 1, entry)
    end
  end
  return list
end

--- Creates jj workspace `ws` for project `name` at
--- `<workspace_dir>/<name>/<ws>`. Its working copy sits on the same parent as
--- the project's own.
--- @param name string
--- @param ws string
--- @return string? path of the new workspace
function M.add_workspace(name, ws)
  local project = find(name)
  if not project then
    vim.notify(("projects: unknown name '%s'"):format(name), vim.log.levels.ERROR)
    return
  end
  -- the name is also a folder name, so it can't nest or hide
  if ws == '' or ws:find('[/\\]') or ws:find('^%.') then
    vim.notify(
      ("projects: '%s' is not a valid workspace name"):format(ws),
      vim.log.levels.ERROR
    )
    return
  end
  local path = vim.fs.joinpath(opts.workspace_dir, name, ws)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local args = { 'workspace', 'add', '--name', ws, path }
  local out, err = jj(project.path, args)
  if not out then return jj_failed(args, err) end
  return path
end

--- Position of this server's project in `M.names()`, or nil when it is none.
--- A project server knows by its own socket, whatever its cwd. Any other nvim
--- goes by cwd: a project's folder, or one of its workspaces under
--- `workspace_dir`.
--- @return number?
function M.current_index()
  local all = list()
  local self = self_server()
  for i, p in ipairs(all) do
    if p.name == self then return i end
  end
  local cwd = vim.fn.resolve(vim.fn.getcwd())
  for i, p in ipairs(all) do
    if vim.fn.resolve(p.path) == cwd then return i end
    local ws_root = vim.fn.resolve(vim.fs.joinpath(opts.workspace_dir, p.name))
    if vim.fs.dirname(cwd) == ws_root then return i end
  end
end

function M.current_name()
  local i = M.current_index()
  if i then return list()[i].name end
  return vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
end

--- Name of the jj workspace this nvim is in. A project server knows by its own
--- socket. Any other nvim goes by cwd: 'default' in the project's own folder,
--- the folder name under `workspace_dir` otherwise. Nil outside a project or a
--- jj repo. Read from the filesystem rather than jj, so it is cheap enough for
--- the statusline.
--- @return string?
function M.current_workspace()
  local i = M.current_index()
  if not i then return end
  local p = list()[i]
  local has_jj = vim.uv.fs_stat(vim.fs.joinpath(p.path, '.jj')) ~= nil
  local _, self_ws = self_server()
  if self_ws then
    if self_ws ~= 'default' or has_jj then return self_ws end
    return
  end
  local cwd = vim.fn.resolve(vim.fn.getcwd())
  local ws_root = vim.fn.resolve(vim.fs.joinpath(opts.workspace_dir, p.name))
  if vim.fs.dirname(cwd) == ws_root then return vim.fs.basename(cwd) end
  if cwd == vim.fn.resolve(p.path) and has_jj then return 'default' end
end

--- `M.current_name()`, with the workspace after a slash unless it is
--- `default`, e.g. 'nvim/feature'.
--- @return string
function M.current_label() return M.label(M.current_name(), M.current_workspace()) end

function M.starter_items()
  local items = {}
  for _, p in ipairs(list()) do
    items[#items + 1] = {
      name = p.name,
      action = ("lua require('huey.projects').connect('%s')"):format(p.name),
      section = 'Projects',
    }
  end
  return items
end

--- Project names: pinned first, then in the order they were added.
--- @return string[]
function M.names()
  return vim.tbl_map(function(p) return p.name end, list())
end

--- Project paths, in the same order as `M.names()`.
--- @return string[]
function M.paths()
  return vim.tbl_map(function(p) return p.path end, list())
end

--- `:connect` to the server of the next/previous jj workspace of this
--- project, in `M.workspaces()` order, starting it if needed; bound to `[w` /
--- `]w` / `[W` / `]W`. Shaped after `MiniBracketed.window()`.
--- @param direction string 'first' | 'backward' | 'forward' | 'last'
--- @param o table? { n_times = v:count1, wrap = true }
function M.workspace_bracketed(direction, o)
  o = vim.tbl_deep_extend('force', { n_times = vim.v.count1, wrap = true }, o or {})

  local i = M.current_index()
  if not i then
    return vim.notify('projects: not in a project', vim.log.levels.WARN)
  end
  local name = list()[i].name
  local all = M.workspaces(name)
  if not all then
    return vim.notify(
      ('projects: %s is not a jj repo'):format(name),
      vim.log.levels.WARN
    )
  end

  -- a server is in the workspace it serves; any other nvim, the one its cwd is in
  local _, self_ws = self_server()
  local cwd = vim.fn.resolve(vim.fn.getcwd())
  local state = 0
  for j, w in ipairs(all) do
    local here
    if self_ws then
      here = w.name == self_ws
    else
      here = vim.fn.resolve(w.path) == cwd
    end
    if here then state = j end
  end
  local iterator = {
    next = function(j) return j < #all and j + 1 or nil end,
    prev = function(j) return j > 1 and j - 1 or nil end,
    -- 0 (== `start_edge`) when in no workspace, so `]w` lands on the first
    -- one and `[w` wraps to the last
    state = state,
    start_edge = 0,
    end_edge = #all + 1,
  }

  local res = require('mini.bracketed').advance(iterator, direction, o)
  if res == state or not all[res] then return end
  M.connect(name, all[res].name)
end

--- Close this server, moving the UI to the next running one (`M.servers()`
--- order, wrapping) when there is one: `:connect!` stops the server it
--- detaches from. With no other server running there is nowhere to land, so
--- just quit. An nvim that is no project server starts from the first.
function M.quit()
  local all = M.servers()
  local self_name, self_ws = self_server()
  local state = 0
  for j, s in ipairs(all) do
    if s.project == self_name and s.workspace == self_ws then state = j end
  end
  local iterator = {
    next = function(j) return j < #all and j + 1 or nil end,
    prev = function(j) return j > 1 and j - 1 or nil end,
    state = state,
    start_edge = 0,
    end_edge = #all + 1,
  }
  -- `n_times` is pinned to 1 on purpose: this closes a server, so a stray
  -- count must not skip past others.
  local res = require('mini.bracketed').advance(iterator, 'forward', { n_times = 1 })
  local target = res ~= state and all[res]
  if not target then return vim.cmd('qa') end
  M.connect(target.project, target.workspace, true)
end

function M.setup(user)
  opts = vim.tbl_extend('force', defaults, user or {})
  cache = {}
  if not is_win then vim.fn.mkdir(opts.server_dir, 'p') end

  vim.api.nvim_create_user_command('ProjectConnect', function(o)
    local name, ws = parse_label(o.args)
    M.connect(name, ws)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_map(
        function(t) return M.label(t.project, t.workspace) end,
        M.targets()
      )
    end,
    desc = "Connect UI to a project workspace's nvim server (spawn if needed)",
  })

  vim.api.nvim_create_user_command('ProjectStop', function(o)
    -- a bare project name stops all of its servers
    local name, ws = parse_label(o.args)
    M.stop(name, o.args:find('/') and ws or nil)
  end, {
    nargs = 1,
    complete = function()
      local out = M.names()
      for _, s in ipairs(M.servers()) do
        if s.workspace ~= 'default' then
          out[#out + 1] = M.label(s.project, s.workspace)
        end
      end
      return out
    end,
    desc = "Stop a project's nvim servers, or one workspace's",
  })

  vim.api.nvim_create_user_command('ProjectQuit', M.quit, {
    desc = 'Stop this server, connecting the UI to the next running one',
  })

  vim.api.nvim_create_user_command('ProjectBots', M.pick_bots, {
    desc = 'Pick a terminal with a status from any running server',
  })

  vim.api.nvim_create_user_command(
    'ProjectAdd',
    function(o) return o.args == '' and M.pick_add() or M.add(o.args) end,
    {
      nargs = '?',
      complete = 'dir',
      desc = 'Add a folder as a project; picks one under home when none is given',
    }
  )
end

return M
