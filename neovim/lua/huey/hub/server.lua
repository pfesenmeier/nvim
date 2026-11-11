-- The hub: one daemon per user that every nvim sends agent statuses to, and
-- that watchers (the TUI) subscribe to. Run with `huey serve`.
local proto = require('huey.hub.proto')
local uv = vim.uv

local Server = {}

--- @type table<string, huey.Agent>
local agents = {}

--- @class huey.Conn
--- @field pipe uv.uv_pipe_t
--- @field role? 'nvim'|'watch'
--- @field pid? integer
--- @field server? string

--- @type table<uv.uv_pipe_t, huey.Conn>
local conns = {}

local idle_ms = tonumber(vim.env.HUEY_IDLE_MS) or 30000
local idle_timer = assert(uv.new_timer())

-- read up front: vim.fn cannot be called from the uv callbacks below
local log_path = vim.fs.joinpath(vim.fn.stdpath('log'), 'huey-hub.log')
local is_win = vim.fn.has('win32') == 1
local sock_path = proto.socket_path()
local stopped = false

--- @param msg string
local log = function(msg)
  local f = io.open(log_path, 'a')
  if not f then return end
  f:write(os.date('%Y-%m-%d %H:%M:%S '), msg, '\n')
  f:close()
end

--- @param conn huey.Conn
--- @param msg table
local send = function(conn, msg)
  if conn.pipe:is_closing() then return end
  conn.pipe:write(proto.encode(msg))
end

--- @param msg table
local broadcast = function(msg)
  for _, conn in pairs(conns) do
    if conn.role == 'watch' then send(conn, msg) end
  end
end

--- @param id string
local remove = function(id)
  if not agents[id] then return end
  agents[id] = nil
  broadcast({ t = 'remove', id = id })
end

local stop
--- Exits once nothing has been connected for a while, so a stale hub (old
--- code, no nvims left) does not linger.
local check_idle = function()
  if next(conns) then return idle_timer:stop() end
  idle_timer:start(idle_ms, 0, function()
    if not next(conns) then stop() end
  end)
end

--- @param conn huey.Conn
--- @param msg table
local handle = function(conn, msg)
  if msg.t == 'hello' then
    conn.role, conn.pid, conn.server = msg.role, msg.pid, msg.server
    if conn.role == 'watch' then
      send(conn, { t = 'snapshot', agents = vim.tbl_values(agents) })
    end
  elseif msg.t == 'status' and conn.role == 'nvim' then
    local agent = msg
    agent.t = nil
    agent.pid, agent.server = conn.pid, conn.server
    agent.id = ('%d:%d'):format(conn.pid, msg.buf)
    agents[agent.id] = agent
    broadcast({ t = 'update', agent = agent })
  elseif msg.t == 'gone' and conn.role == 'nvim' then
    remove(('%d:%d'):format(conn.pid, msg.buf))
  end
end

--- @param conn huey.Conn
local drop = function(conn)
  if not conns[conn.pipe] then return end
  conns[conn.pipe] = nil
  if not conn.pipe:is_closing() then conn.pipe:close() end
  -- an nvim that hung up (or crashed) takes its agents with it
  if conn.role == 'nvim' then
    for id, agent in pairs(agents) do
      if agent.pid == conn.pid then remove(id) end
    end
  end
  check_idle()
end

local listener
stop = function()
  if listener and not listener:is_closing() then listener:close() end
  for _, conn in pairs(conns) do
    if not conn.pipe:is_closing() then conn.pipe:close() end
  end
  idle_timer:close()
  if not is_win then pcall(os.remove, sock_path) end
  stopped = true
end

--- True when another hub answers on `path`.
--- @param path string
--- @return boolean
local someone_listening = function(path)
  local probe = assert(uv.new_pipe(false))
  local done, alive = false, false
  probe:connect(path, function(err)
    alive, done = not err, true
    probe:close()
  end)
  vim.wait(1000, function() return done end, 10)
  return alive
end

--- @param path string
--- @return boolean bound
local bind = function(path)
  listener = assert(uv.new_pipe(false))
  if listener:bind(path) then return true end

  -- Windows refuses a second bind outright; on unix the path may be a socket
  -- left behind by a hub that crashed
  if is_win or someone_listening(path) then return false end
  os.remove(path)
  listener:close()
  listener = assert(uv.new_pipe(false))
  return listener:bind(path) ~= nil
end

--- Runs the hub until it goes idle. Exits quietly when another hub already
--- owns the socket, which is how two nvims starting at once settle on one.
Server.run = function()
  local path = sock_path
  if not bind(path) then return end
  log('listening on ' .. path)

  listener:listen(16, function(err)
    if err then return log('listen: ' .. err) end
    local pipe = assert(uv.new_pipe(false))
    listener:accept(pipe)
    local conn = { pipe = pipe }
    conns[pipe] = conn
    check_idle()

    local read = proto.reader(function(msg)
      local ok, herr = pcall(handle, conn, msg)
      if not ok then log('handle: ' .. tostring(herr)) end
    end)
    pipe:read_start(function(rerr, chunk)
      if rerr or not chunk then return drop(conn) end
      read(chunk)
    end)
  end)

  check_idle()
  -- `nvim -l` already runs a uv loop; wait on it rather than starting another
  while not stopped do
    vim.wait(60000, function() return stopped end, 1000)
  end
  log('stopped')
end

return Server
