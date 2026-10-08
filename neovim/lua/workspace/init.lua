local M = {}

-- A stable, per-user socket directory shared by every nvim process (the TUI
-- and all headless workspace servers). It MUST be identical across processes
-- so they can discover each other's sockets via probe().
--
-- On Linux, stdpath("run") is $XDG_RUNTIME_DIR/nvim.user and is stable. On
-- macOS, XDG_RUNTIME_DIR is unset and stdpath("run") falls back to a temp dir
-- that is *unique per process* -- so each process would look in a different
-- place, never reuse a server, and keep spawning competing duplicates. Use a
-- stable TMPDIR-based path there instead.
local function default_server_dir()
  if vim.env.XDG_RUNTIME_DIR and vim.env.XDG_RUNTIME_DIR ~= '' then
    return vim.fn.stdpath('run') .. '/workspaces'
  end
  local tmp = (vim.env.TMPDIR or '/tmp'):gsub('/+$', '')
  return tmp .. '/nvim-workspaces-' .. (vim.env.USER or vim.env.LOGNAME or 'user')
end

local defaults = {
  workspaces = {}, -- list of { name = string, path = string }
  server_dir = default_server_dir(),
}

local opts = defaults

local function sock_for(name) return opts.server_dir .. '/' .. name .. '.sock' end

local function find_ws(name)
  for _, ws in ipairs(opts.workspaces) do
    if ws.name == name then return ws end
  end
end

local function probe(sock)
  if not vim.loop.fs_stat(sock) then return false end
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
  if not ok or chan == 0 then return false end
  pcall(vim.fn.chanclose, chan)
  return true
end

-- Run a Lua chunk in the server at `sock` and return its result, or nil when
-- the server is unreachable or the chunk errors.
local function rpc_lua(sock, code, args)
  if not vim.loop.fs_stat(sock) then return nil end
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
  if not ok or chan == 0 then return nil end
  local got, res = pcall(vim.rpcrequest, chan, 'nvim_exec_lua', code, args or {})
  pcall(vim.fn.chanclose, chan)
  if got and res ~= vim.NIL then return res end
end

-- True when `sock` is one of this process's own listen addresses.
local function is_self(sock) return vim.tbl_contains(vim.fn.serverlist(), sock) end

function M.status(name) return probe(sock_for(name)) and 'running' or 'stopped' end

local function spawn(ws)
  local sock = sock_for(ws.name)
  vim.fn.jobstart({
    'nvim',
    '--listen',
    sock,
    '--headless',
    '--cmd',
    'cd ' .. vim.fn.fnameescape(ws.path),
  }, { detach = true })
  if not vim.wait(2000, function() return probe(sock) end, 50) then
    vim.notify(
      ('workspace: timed out waiting for %s'):format(sock),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

--- @param name string
--- @param stop_current boolean? use `:connect!`, stopping the server left behind
function M.connect(name, stop_current)
  local ws = find_ws(name)
  if not ws then
    vim.notify(("workspace: unknown name '%s'"):format(name), vim.log.levels.ERROR)
    return
  end
  local addr = sock_for(name)
  if not probe(addr) and not spawn(ws) then return end
  vim.cmd((stop_current and 'connect! ' or 'connect ') .. vim.fn.fnameescape(addr))
end

function M.stop(name)
  local sock = sock_for(name)
  if not probe(sock) then
    vim.notify(('workspace: %s is not running'):format(name), vim.log.levels.WARN)
    return
  end
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
  if not ok or chan == 0 then return end
  pcall(vim.rpcnotify, chan, 'nvim_command', 'qa!')
  pcall(vim.fn.chanclose, chan)
  vim.wait(1000, function() return not vim.loop.fs_stat(sock) end, 50)
  pcall(os.remove, sock)
end

function M.pick()
  local glyph = function(status) return status == 'running' and '●' or '○' end
  local row = function(status, name, trailing)
    return ('%s  %-20s  %s'):format(glyph(status), name, trailing)
  end
  local items = {}
  for _, ws in ipairs(opts.workspaces) do
    items[#items + 1] = {
      name = ws.name,
      text = row(M.status(ws.name), ws.name, ws.path),
    }
  end
  MiniPick.start({
    source = {
      name = 'Workspaces',
      items = items,
      choose = function(item)
        if not item then return end
        vim.schedule(function() M.connect(item.name) end)
      end,
    },
  })
end

--- Run a Lua chunk in every running workspace server, in configuration order.
--- This server runs it in-process rather than over RPC.
--- @param code string Lua chunk; receives `args` as `...`
--- @param args any[]?
--- @return { ws: string, result: any }[] nil results are skipped
function M.collect(code, args)
  args = args or {}
  local out = {}
  for _, ws in ipairs(opts.workspaces) do
    local sock = sock_for(ws.name)
    local res
    if is_self(sock) then
      res = assert(loadstring(code))(unpack(args))
    elseif M.status(ws.name) == 'running' then
      res = rpc_lua(sock, code, args)
    end
    if res ~= nil then out[#out + 1] = { ws = ws.name, result = res } end
  end
  return out
end

-- Terminals with a tabline status icon (see 'huey/term.lua'). Empty in a server
-- that never set up HueyTerm.
local list_bots = [[
  local term = rawget(_G, 'HueyTerm')
  if not term then return {} end
  local out = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local icon = vim.api.nvim_buf_is_valid(b)
      and vim.bo[b].buftype == 'terminal'
      and term.get_icon(b)
    if icon then
      out[#out + 1] = { bufnr = b, name = vim.api.nvim_buf_get_name(b), icon = icon }
    end
  end
  return out
]]

--- Picker rows for every terminal with a status in a running workspace. Read
--- live from each server on every call; nothing is cached.
--- @return table[]
function M.bot_items()
  local items = {}
  for _, r in ipairs(M.collect(list_bots)) do
    for _, b in ipairs(r.result) do
      items[#items + 1] = {
        ws = r.ws,
        -- not `bufnr`: MiniPick would treat it as a buffer in this process
        remote_buf = b.bufnr,
        name = b.name,
        text = ('%s  %-12s %s'):format(
          b.icon,
          r.ws,
          vim.fn.fnamemodify(b.name, ':~')
        ),
      }
    end
  end
  return items
end

local refresh_ms = 1000

--- Pick a terminal with a status from any running workspace. Rows refresh
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
    local sock = sock_for(item.ws)
    if not is_self(sock) then return rpc_lua(sock, code, { item.remote_buf }) end
    -- the buffer may be gone by now; fail quietly like the RPC path does
    local ok, res = pcall(assert(loadstring(code)), item.remote_buf)
    if ok then return res end
  end

  MiniPick.start({
    source = {
      name = 'Bots (workspaces)',
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
          if not is_self(sock_for(item.ws)) then M.connect(item.ws) end
        end)
      end,
    },
  })
end

function M.current_name()
  local cwd = vim.fn.resolve(vim.fn.getcwd())
  for _, ws in ipairs(opts.workspaces) do
    if vim.fn.resolve(vim.fn.expand(ws.path)) == cwd then return ws.name end
  end
  return vim.fn.fnamemodify(cwd, ':t')
end

--- Position of the cwd's workspace in `M.names()`, or nil when cwd is not one.
--- @return number?
function M.current_index()
  local cwd = vim.fn.resolve(vim.fn.getcwd())
  for i, ws in ipairs(opts.workspaces) do
    if vim.fn.resolve(vim.fn.expand(ws.path)) == cwd then return i end
  end
end

function M.starter_items()
  local items = {}
  for _, ws in ipairs(opts.workspaces) do
    items[#items + 1] = {
      name = ws.name,
      action = ("lua require('workspace').connect('%s')"):format(ws.name),
      section = 'Workspaces',
    }
  end
  return items
end

--- Configured workspace names, in configuration order.
--- @return string[]
function M.names()
  local out = {}
  for _, ws in ipairs(opts.workspaces) do
    out[#out + 1] = ws.name
  end
  return out
end

--- Name of the next/previous *running* workspace, skipping stopped ones, or nil
--- when there is none to move to. Shaped after `MiniBracketed.window()`.
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
    -- The origin need not be running: the TUI can sit in a workspace directory
    -- whose server was never spawned. 0 (== `start_edge`) when cwd is no
    -- workspace at all, so `]w` lands on the first running one and `[w` wraps.
    state = M.current_index() or 0,
    start_edge = 0,
    end_edge = #all + 1,
  }

  local res = require('mini.bracketed').advance(iterator, direction, o)
  if res == iterator.state then return end

  return all[res]
end

--- Connect to the next/previous *running* workspace; bound to `[w` / `]w` /
--- `[W` / `]W`.
--- @param direction string 'first' | 'backward' | 'forward' | 'last'
--- @param o table? { n_times = v:count1, wrap = true }
function M.bracketed(direction, o)
  local name = advance(direction, o)
  if name then M.connect(name) end
end

--- Close this workspace's server, moving the UI to the next running workspace
--- when there is one: `:connect!` stops the server it detaches from. With no
--- other workspace running there is nowhere to land, so just quit.
function M.quit()
  -- `n_times` is pinned to 1 on purpose: unlike `]w`, this closes a server, so
  -- a stray count must not skip past workspaces.
  local target = advance('forward', { n_times = 1 })
  if not target then return vim.cmd('qa') end
  M.connect(target, true)
end

local function workspaces_from_env()
  local raw = vim.env.WORKSPACES
  if not raw or raw == '' then return nil end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= 'table' then
    vim.notify('workspace: failed to decode $WORKSPACES', vim.log.levels.WARN)
    return nil
  end
  return decoded
end

function M.setup(user)
  user = user or {}
  if not user.workspaces then user.workspaces = workspaces_from_env() end
  opts = vim.tbl_deep_extend('force', defaults, user)
  vim.fn.mkdir(opts.server_dir, 'p')

  vim.api.nvim_create_user_command(
    'WorkspaceConnect',
    function(o) M.connect(o.args) end,
    {
      nargs = 1,
      complete = function() return M.names() end,
      desc = "Connect UI to a workspace's nvim server (spawn if needed)",
    }
  )

  vim.api.nvim_create_user_command('WorkspaceStop', function(o) M.stop(o.args) end, {
    nargs = 1,
    complete = function() return M.names() end,
    desc = "Stop a workspace's nvim server",
  })

  vim.api.nvim_create_user_command('WorkspaceQuit', M.quit, {
    desc = "Stop this workspace's server, connecting the UI to the next running one",
  })

  vim.api.nvim_create_user_command('WorkspaceBots', M.pick_bots, {
    desc = 'Pick a terminal with a status from any running workspace',
  })
end

return M
