-- `huey tui`: a live table of every agent across nvims, read from the hub, for
-- terminals outside nvim. Inside nvim, `:HueyAgents` shows the same in a buffer.
-- `huey list`: the same agents as JSON.
local proto = require('huey.hub.proto')
local View = require('huey.hub.view')
local uv = vim.uv

local Tui = {}
local H = {}

--- @type table<string, huey.Agent>
local agents = {}
local selected = 1
local footer = ''
local done = false

local stdout, stdin

H.draw = function()
  local cols, lines = stdout:get_winsize()
  cols, lines = cols or 80, lines or 24
  local now = os.time()
  local rows = View.rows(agents)
  selected = math.max(1, math.min(selected, #rows))

  local out = { '\27[H\27[2J' }
  out[#out + 1] = '\27[1m' .. View.fit(View.header(), cols) .. '\27[0m\r\n'

  if #rows == 0 then out[#out + 1] = '\27[2m   no agents\27[0m\r\n' end

  -- the selected row stays on screen
  local room = lines - 3
  local first = math.max(1, selected - room + 1)
  for i = first, math.min(#rows, first + room - 1) do
    local line = View.fit((View.line(rows[i], now)), cols)
    if i == selected then line = '\27[7m' .. View.pad(line, cols) .. '\27[0m' end
    out[#out + 1] = line .. '\r\n'
  end

  local help = 'j/k move  enter jump  q quit'
  out[#out + 1] = ('\27[%d;1H\27[2m%s\27[0m'):format(
    lines,
    View.fit(footer ~= '' and footer or help, cols)
  )
  stdout:write(table.concat(out))
end

--- Show `agent`'s terminal in its nvim, and move the nvim this TUI runs in
--- (if any) over to that nvim.
--- @param agent huey.Agent
H.jump = function(agent)
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', agent.server, { rpc = true })
  if not ok or chan == 0 then
    footer = 'cannot reach ' .. (agent.server or '?')
    return
  end
  pcall(vim.rpcrequest, chan, 'nvim_exec_lua', 'vim.cmd.buffer(...)', { agent.buf })
  pcall(vim.fn.chanclose, chan)

  local parent = vim.env.NVIM
  if parent and parent ~= '' and parent ~= agent.server then
    local pok, pchan = pcall(vim.fn.sockconnect, 'pipe', parent, { rpc = true })
    if pok and pchan ~= 0 then
      -- scheduled so the request returns before `:connect` detaches the UI
      local code = 'local a = ...; vim.schedule(function() vim.cmd.connect(a) end)'
      pcall(vim.rpcrequest, pchan, 'nvim_exec_lua', code, { agent.server })
      pcall(vim.fn.chanclose, pchan)
    end
  end
  footer = 'switched to ' .. vim.fs.basename(agent.name or '') .. ' in ' .. (agent.workspace or '?')
end

--- Splits a stdin chunk into keys; arrow keys arrive as `ESC [ A`.
--- @param chunk string
--- @return string[]
H.keys = function(chunk)
  local out, i = {}, 1
  while i <= #chunk do
    local len = chunk:sub(i, i + 1) == '\27[' and 3 or 1
    out[#out + 1] = chunk:sub(i, i + len - 1)
    i = i + len
  end
  return out
end

--- @param key string
H.on_key = function(key)
  local rows = View.rows(agents)
  footer = ''
  if key == 'q' or key == '\3' then
    done = true
  elseif key == 'j' or key == '\27[B' then
    selected = math.min(#rows, selected + 1)
  elseif key == 'k' or key == '\27[A' then
    selected = math.max(1, selected - 1)
  elseif key == '\r' or key == '\n' then
    if rows[selected] then H.jump(rows[selected]) end
  end
  H.draw()
end

--- Connect as a watcher, starting a hub when none is running.
--- @param on_msg fun(msg: table)
--- @param on_close fun()
--- @return uv.uv_pipe_t?
H.watch = function(on_msg, on_close)
  local result
  proto.reach(on_msg, on_close, function(p) result = p or false end)
  vim.wait(10000, function() return result ~= nil end, 10)
  if not result then return end
  result:write(proto.encode({ t = 'hello', role = 'watch' }))
  return result
end

--- Print every agent as JSON and exit.
Tui.list = function()
  local snapshot
  local pipe = H.watch(function(msg)
    if msg.t == 'snapshot' then snapshot = msg.agents end
  end, function() snapshot = snapshot or {} end)
  if not pipe then
    io.stderr:write('huey: could not reach the hub\n')
    os.exit(1)
  end
  vim.wait(2000, function() return snapshot ~= nil end, 10)
  io.stdout:write(vim.json.encode(snapshot or {}), '\n')
  pipe:close()
end

Tui.run = function()
  stdout = assert(uv.new_tty(1, false))
  stdin = assert(uv.new_tty(0, true))

  local dirty = true
  local lost = false
  local on_msg = function(msg)
    View.apply(agents, msg)
    dirty = true
  end
  local pipe = H.watch(on_msg, function() lost = true end)
  if not pipe then
    io.stderr:write('huey: could not reach the hub\n')
    os.exit(1)
  end

  local restore = function()
    stdin:set_mode(0)
    stdout:write('\27[?25h\27[?1049l')
  end

  local ok, err = xpcall(function()
    stdin:set_mode(1)
    stdout:write('\27[?1049h\27[?25l')

    local keys = {}
    stdin:read_start(function(_, data)
      if data then table.insert(keys, data) end
    end)

    local winch = uv.new_signal()
    if winch then winch:start('sigwinch', function() dirty = true end) end

    local last_tick = 0
    while not done do
      -- wakes on any hub message or key; ages refresh once a second
      vim.wait(1000, function() return dirty or #keys > 0 or lost end, 20)
      for _, chunk in ipairs(keys) do
        for _, key in ipairs(H.keys(chunk)) do
          H.on_key(key)
        end
      end
      keys = {}
      if lost then
        lost = false
        footer = 'lost the hub, reconnecting'
        pipe = H.watch(on_msg, function() lost = true end) or pipe
      end
      if dirty or os.time() ~= last_tick then
        dirty = false
        last_tick = os.time()
        H.draw()
      end
    end
  end, debug.traceback)

  restore()
  if not ok then
    io.stderr:write(err, '\n')
    os.exit(1)
  end
  pipe:close()
end

return Tui
