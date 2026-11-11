-- Shared by the hub daemon, the TUI, and the client inside each nvim.
-- Runs under `nvim -l` too, so it only uses `vim.uv`, `vim.json` and `vim.fn`.
local Proto = {}

--- @class huey.Agent
--- @field id string `<pid>:<buf>`, unique across nvims
--- @field pid integer nvim process that owns the terminal
--- @field server string that nvim's `v:servername`, for jumping to it
--- @field buf integer terminal buffer in that nvim
--- @field name string terminal buffer name
--- @field workspace string
--- @field cwd string
--- @field state string idle | working | done | blocked | error
--- @field kind? string permission | question | auth, when blocked
--- @field progress? integer 0-100, when working
--- @field title? string what the agent says it is working on
--- @field msg? string why it is blocked
--- @field app? string e.g. 'claude-code'
--- @field started integer epoch seconds of its first status
--- @field changed integer epoch seconds its state last changed

--- Where the hub listens. One hub per user per machine.
--- @return string
Proto.socket_path = function()
  if vim.env.HUEY_SOCK and vim.env.HUEY_SOCK ~= '' then return vim.env.HUEY_SOCK end

  local user = vim.env.USER or vim.env.USERNAME or vim.env.LOGNAME or 'user'
  if vim.fn.has('win32') == 1 then return [[\\.\pipe\huey-]] .. user end

  -- Same reason as 'workspace': stdpath('run') is unique per process on macOS
  if vim.env.XDG_RUNTIME_DIR and vim.env.XDG_RUNTIME_DIR ~= '' then
    return vim.env.XDG_RUNTIME_DIR .. '/huey.sock'
  end
  local tmp = (vim.env.TMPDIR or '/tmp'):gsub('/+$', '')
  return tmp .. '/huey-' .. user .. '.sock'
end

--- Path of `bin/huey` in this repo, found from this file's own location.
--- @return string
Proto.script_path = function()
  local here = debug.getinfo(1, 'S').source:sub(2)
  here = vim.uv.fs_realpath(here) or here
  -- neovim/lua/huey/hub/proto.lua -> repo root
  local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))))
  return vim.fs.joinpath(root, 'bin', 'huey')
end

--- Starts a hub in the background. Safe to call when one is already running:
--- the second one sees the first and exits.
Proto.spawn_hub = function()
  local exe = vim.v.progpath ~= '' and vim.v.progpath or 'nvim'
  vim.fn.jobstart({ exe, '-l', Proto.script_path(), 'serve' }, { detach = true })
end

--- @param msg table
--- @return string
Proto.encode = function(msg) return vim.json.encode(msg) .. '\n' end

--- Turns a byte stream into decoded messages, one per line.
--- @param on_msg fun(msg: table)
--- @return fun(chunk: string)
Proto.reader = function(on_msg)
  local pending = ''
  return function(chunk)
    pending = pending .. chunk
    while true do
      local nl = pending:find('\n', 1, true)
      if not nl then return end
      local line = pending:sub(1, nl - 1)
      pending = pending:sub(nl + 1)
      local ok, msg = pcall(vim.json.decode, line, { luanil = { object = true } })
      if ok and type(msg) == 'table' then on_msg(msg) end
    end
  end
end

--- Opens a connection to the hub.
--- @param on_msg fun(msg: table)
--- @param on_close fun()
--- @param cb fun(pipe: uv.uv_pipe_t?) nil when nothing is listening
Proto.connect = function(on_msg, on_close, cb)
  local pipe = assert(vim.uv.new_pipe(false))
  pipe:connect(Proto.socket_path(), function(err)
    if err then
      pipe:close()
      return cb(nil)
    end
    local read = Proto.reader(on_msg)
    pipe:read_start(function(rerr, chunk)
      if rerr or not chunk then
        if not pipe:is_closing() then pipe:close() end
        return on_close()
      end
      read(chunk)
    end)
    cb(pipe)
  end)
end

--- Icons for each state, shared by the tabline and the TUI.
local moons = { '○', '◔', '◑', '◕', '●' }

--- @param state string
--- @param progress integer?
--- @return string?
Proto.icon = function(state, progress)
  if state == 'working' then
    if not progress then return '∿' end
    -- stops at three quarters, so a full moon always means done
    local idx = math.max(0, math.min(3, math.floor(progress / 25 + 0.5)))
    return moons[idx + 1]
  end
  if state == 'blocked' then return '⏸' end
  if state == 'done' then return '●' end
  if state == 'error' then return '⊘' end
  if state == 'idle' then return '·' end
end

return Proto
