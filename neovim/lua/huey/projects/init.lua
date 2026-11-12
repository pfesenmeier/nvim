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
}

local opts = defaults

local function sock_for(name) return opts.server_dir .. '/' .. name .. '.sock' end

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

function M.status(name) return probe(sock_for(name)) and 'running' or 'stopped' end

local function spawn(project)
  local sock = sock_for(project.name)
  -- progpath, not 'nvim': run the same nvim binary as this one
  vim.fn.jobstart({
    vim.v.progpath ~= '' and vim.v.progpath or 'nvim',
    '--listen',
    sock,
    '--headless',
    '--cmd',
    'cd ' .. vim.fn.fnameescape(project.path),
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

--- Address of `name`'s server, starting it when it isn't running. Nil when
--- the name is unknown or the server didn't come up.
--- @param name string
--- @return string?
function M.ensure(name)
  local project = find(name)
  if not project then
    vim.notify(("projects: unknown name '%s'"):format(name), vim.log.levels.ERROR)
    return
  end
  local addr = sock_for(name)
  if not probe(addr) and not spawn(project) then return end
  return addr
end

--- @param name string
--- @param stop_current boolean? use `:connect!`, stopping the server left behind
function M.connect(name, stop_current)
  local addr = M.ensure(name)
  if not addr then return end
  vim.cmd((stop_current and 'connect! ' or 'connect ') .. vim.fn.fnameescape(addr))
end

function M.stop(name)
  local sock = sock_for(name)
  if not probe(sock) then
    vim.notify(('projects: %s is not running'):format(name), vim.log.levels.WARN)
    return
  end
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
  if not ok or chan == 0 then return end
  pcall(vim.rpcnotify, chan, 'nvim_command', 'qa!')
  pcall(vim.fn.chanclose, chan)
  vim.wait(1000, function() return not probe(sock) end, 50)
  if not is_win then pcall(os.remove, sock) end
end

function M.pick()
  local glyph = function(status) return status == 'running' and '●' or '○' end
  local row = function(status, name, trailing)
    return ('%s  %-20s  %s'):format(glyph(status), name, trailing)
  end
  local items = {}
  for _, p in ipairs(list()) do
    items[#items + 1] = {
      name = p.name,
      text = row(M.status(p.name), p.name, p.path),
    }
  end
  MiniPick.start({
    source = {
      name = 'Projects',
      items = items,
      choose = function(item)
        if not item then return end
        vim.schedule(function() M.connect(item.name) end)
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

--- Run a Lua chunk in every running project server, in configuration order.
--- This server runs it in-process rather than over RPC.
--- @param code string Lua chunk; receives `args` as `...`
--- @param args any[]?
--- @return { project: string, result: any }[] nil results are skipped
function M.collect(code, args)
  args = args or {}
  local out = {}
  for _, p in ipairs(list()) do
    local sock = sock_for(p.name)
    local res
    if is_self(sock) then
      res = assert(loadstring(code))(unpack(args))
    elseif M.status(p.name) == 'running' then
      res = rpc_lua(sock, code, args)
    end
    if res ~= nil then out[#out + 1] = { project = p.name, result = res } end
  end
  return out
end

-- Terminals with a tabline status icon (see 'huey/term.lua'), plus running ones
-- that reported a status before but have none now, shown as idle. Empty in
-- a server that never set up HueyTerm.
local list_bots = [[
  local term = rawget(_G, 'HueyTerm')
  if not term then return {} end
  local out = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local icon = vim.api.nvim_buf_is_valid(b)
      and vim.bo[b].buftype == 'terminal'
      and (term.get_icon(b) or (term.is_bot and term.is_bot(b) and '·'))
    if icon then
      out[#out + 1] = {
        bufnr = b,
        name = vim.api.nvim_buf_get_name(b),
        icon = icon,
        title = vim.b[b].term_title,
      }
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

--- Picker rows for every terminal with a status in a running project. Read
--- live from each server on every call; nothing is cached.
--- @return table[]
function M.bot_items()
  local items = {}
  for _, r in ipairs(M.collect(list_bots)) do
    for _, b in ipairs(r.result) do
      items[#items + 1] = {
        project = r.project,
        -- not `bufnr`: MiniPick would treat it as a buffer in this process
        remote_buf = b.bufnr,
        name = b.name,
        text = ('%s  %-12s %s'):format(
          b.icon,
          r.project,
          summary(b.title) or vim.fn.fnamemodify(b.name, ':~')
        ),
      }
    end
  end
  return items
end

local refresh_ms = 1000

--- Pick a terminal with a status from any running project. Rows refresh
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

  -- Run in the item's server, locally when that is this one
  local run = function(item, code)
    local sock = sock_for(item.project)
    if not is_self(sock) then return rpc_lua(sock, code, { item.remote_buf }) end
    -- the buffer may be gone by now; fail quietly like the RPC path does
    local ok, res = pcall(assert(loadstring(code)), item.remote_buf)
    if ok then return res end
  end

  MiniPick.start({
    source = {
      name = 'Bots (projects)',
      items = items,
      preview = function(buf_id, item)
        local lines = run(
          item,
          'return vim.api.nvim_buf_get_lines(..., 0, -1, false)'
        ) or {}
        -- terminal buffers pad the end with blank lines
        while #lines > 0 and lines[#lines] == '' do
          lines[#lines] = nil
        end
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        -- the latest output is the interesting part of a terminal
        local win = vim.fn.bufwinid(buf_id)
        if win ~= -1 then
          pcall(vim.api.nvim_win_set_cursor, win, { math.max(#lines, 1), 0 })
        end
      end,
      choose = function(item)
        if not item then return end
        vim.schedule(function()
          run(item, 'vim.cmd.buffer(...)')
          if not is_self(sock_for(item.project)) then M.connect(item.project) end
        end)
      end,
    },
  })
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
--- A project server knows by its own socket, whatever workspace its cwd is in.
--- Any other nvim goes by cwd: a project's folder, or one of its workspaces
--- under `workspace_dir`.
--- @return number?
function M.current_index()
  local all = list()
  for i, p in ipairs(all) do
    if is_self(sock_for(p.name)) then return i end
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

--- Name of the jj workspace the editor's cwd is in: 'default' in the project's
--- own folder when it is a jj repo, the folder name under `workspace_dir`
--- otherwise. Nil outside a project or a jj repo. Read from the filesystem
--- rather than jj, so it is cheap enough for the statusline.
--- @return string?
function M.current_workspace()
  local i = M.current_index()
  if not i then return end
  local p = list()[i]
  local cwd = vim.fn.resolve(vim.fn.getcwd())
  local ws_root = vim.fn.resolve(vim.fs.joinpath(opts.workspace_dir, p.name))
  if vim.fs.dirname(cwd) == ws_root then return vim.fs.basename(cwd) end
  if cwd == vim.fn.resolve(p.path) and vim.uv.fs_stat(cwd .. '/.jj') then
    return 'default'
  end
end

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

--- Name of the next/previous *running* project, skipping stopped ones, or nil
--- when there is none to move to. Used by `M.quit()` to pick where to land.
--- Shaped after `MiniBracketed.window()`.
--- @param direction string 'first' | 'backward' | 'forward' | 'last'
--- @param o table? { n_times = v:count1, wrap = true }
--- @return string?
local function advance(direction, o)
  o = vim.tbl_deep_extend('force', { n_times = vim.v.count1, wrap = true }, o or {})

  local all = M.names()
  local iterator = {
    next = function(i)
      for j = i + 1, #all do
        if M.status(all[j]) == 'running' then return j end
      end
    end,
    prev = function(i)
      for j = i - 1, 1, -1 do
        if M.status(all[j]) == 'running' then return j end
      end
    end,
    -- The origin need not be running: the TUI can sit in a project directory
    -- whose server was never spawned. 0 (== `start_edge`) when cwd is no
    -- project at all, so 'forward' lands on the first running one.
    state = M.current_index() or 0,
    start_edge = 0,
    end_edge = #all + 1,
  }

  local res = require('mini.bracketed').advance(iterator, direction, o)
  if res == iterator.state then return end

  return all[res]
end

--- Change the editor's directory to `path`, a workspace of project `name`.
--- In that project's server this is a plain `:cd`. From anywhere else the
--- project's server is started if needed, changes directory, and then the UI
--- connects to it.
--- @param name string
--- @param path string
function M.cd(name, path)
  local i = M.current_index()
  if i and list()[i].name == name then
    return vim.cmd.cd(vim.fn.fnameescape(path))
  end
  local addr = M.ensure(name)
  if not addr then return end
  rpc_lua(addr, 'vim.cmd.cd(vim.fn.fnameescape(...))', { path })
  M.connect(name)
end

--- `:cd` to the next/previous jj workspace of this server's project, in
--- `M.workspaces()` order; bound to `[w` / `]w` / `[W` / `]W`. Shaped after
--- `MiniBracketed.window()`.
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

  local cwd = vim.fn.resolve(vim.fn.getcwd())
  local state = 0
  for j, w in ipairs(all) do
    if vim.fn.resolve(w.path) == cwd then state = j end
  end
  local iterator = {
    next = function(j) return j < #all and j + 1 or nil end,
    prev = function(j) return j > 1 and j - 1 or nil end,
    -- 0 (== `start_edge`) when cwd is in no workspace, so `]w` lands on the
    -- first one and `[w` wraps to the last
    state = state,
    start_edge = 0,
    end_edge = #all + 1,
  }

  local res = require('mini.bracketed').advance(iterator, direction, o)
  if res == state or not all[res] then return end
  vim.cmd.cd(vim.fn.fnameescape(all[res].path))
end

--- Close this project's server, moving the UI to the next running project
--- when there is one: `:connect!` stops the server it detaches from. With no
--- other project running there is nowhere to land, so just quit.
function M.quit()
  -- `n_times` is pinned to 1 on purpose: this closes a server, so a stray
  -- count must not skip past projects.
  local target = advance('forward', { n_times = 1 })
  if not target then return vim.cmd('qa') end
  M.connect(target, true)
end

function M.setup(user)
  opts = vim.tbl_extend('force', defaults, user or {})
  cache = {}
  if not is_win then vim.fn.mkdir(opts.server_dir, 'p') end

  vim.api.nvim_create_user_command(
    'ProjectConnect',
    function(o) M.connect(o.args) end,
    {
      nargs = 1,
      complete = function() return M.names() end,
      desc = "Connect UI to a project's nvim server (spawn if needed)",
    }
  )

  vim.api.nvim_create_user_command('ProjectStop', function(o) M.stop(o.args) end, {
    nargs = 1,
    complete = function() return M.names() end,
    desc = "Stop a project's nvim server",
  })

  vim.api.nvim_create_user_command('ProjectQuit', M.quit, {
    desc = "Stop this project's server, connecting the UI to the next running one",
  })

  vim.api.nvim_create_user_command('ProjectBots', M.pick_bots, {
    desc = 'Pick a terminal with a status from any running project',
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
