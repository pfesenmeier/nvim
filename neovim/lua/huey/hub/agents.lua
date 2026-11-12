-- `:HueyAgents`: a live list of every agent across nvims, in a buffer.
-- Watches the hub over its own connection while the buffer is open.
local proto = require('huey.hub.proto')
local View = require('huey.hub.view')

local Agents = {}
local H = {}

H.ns = vim.api.nvim_create_namespace('HueyAgents')

H.state_hl = proto.hl

--- @type table<string, huey.Agent>
local agents = {}
--- Agent id on each buffer line
--- @type table<integer, string>
local ids = {}
--- @type integer?
local buf
--- @type uv.uv_pipe_t?
local pipe
--- @type uv.uv_timer_t?
local timer
--- Shown after the header, e.g. while reconnecting
local status = ''
--- Bumped on every (re)connect, so callbacks from an old connection do nothing
local gen = 0
local pending = false

--- @return boolean
H.alive = function() return buf ~= nil and vim.api.nvim_buf_is_valid(buf) end

H.render = function()
  pending = false
  if not H.alive() then return end
  --- @cast buf integer

  -- remember which agent each window's cursor is on
  local wins = vim.fn.win_findbuf(buf)
  local keep = {}
  for _, win in ipairs(wins) do
    keep[win] = ids[vim.api.nvim_win_get_cursor(win)[1]]
  end

  local now = os.time()
  local lines, marks = { View.header() }, {}
  ids = {}
  for _, agent in ipairs(View.rows(agents)) do
    local line, state_end = View.line(agent, now)
    lines[#lines + 1] = line
    ids[#lines] = agent.id
    marks[#lines] = { state_end, H.state_hl[agent.state] }
  end
  if #lines == 1 then lines[2] = '   no agents' end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, H.ns, 0, -1)
  local header = { end_col = #lines[1], hl_group = 'Title' }
  if status ~= '' then
    header.virt_text = { { status, 'WarningMsg' } }
    header.virt_text_pos = 'eol'
  end
  vim.api.nvim_buf_set_extmark(buf, H.ns, 0, 0, header)
  if not ids[2] then
    vim.api.nvim_buf_set_extmark(buf, H.ns, 1, 0, { end_col = #lines[2], hl_group = 'Comment' })
  end
  for lnum, mark in pairs(marks) do
    if mark[2] then
      vim.api.nvim_buf_set_extmark(buf, H.ns, lnum - 1, 0, { end_col = mark[1], hl_group = mark[2] })
    end
  end

  for win, id in pairs(keep) do
    for lnum, line_id in pairs(ids) do
      if line_id == id then vim.api.nvim_win_set_cursor(win, { lnum, 0 }) end
    end
  end
end

--- Batches the hub's burst of messages into one redraw.
H.request_render = function()
  if pending then return end
  pending = true
  vim.schedule(H.render)
end

--- (Re)connects to the hub as a watcher.
H.watch = function()
  gen = gen + 1
  local my = gen
  if pipe and not pipe:is_closing() then pipe:close() end
  pipe = nil

  proto.reach(function(msg)
    vim.schedule(function()
      if my ~= gen then return end
      View.apply(agents, msg)
      H.request_render()
    end)
  end, function()
    vim.schedule(function()
      if my ~= gen or not H.alive() then return end
      pipe = nil
      status = 'lost the hub, reconnecting'
      H.render()
      H.watch()
    end)
  end, function(p)
    if my ~= gen or not H.alive() then
      if p then p:close() end
      return
    end
    if not p then
      status = 'could not reach the hub, r to retry'
      return H.render()
    end
    pipe = p
    status = ''
    p:write(proto.encode({ t = 'hello', role = 'watch' }))
    H.render()
  end)
end

--- Stops watching once the buffer is gone.
H.stop = function()
  gen = gen + 1
  if pipe and not pipe:is_closing() then pipe:close() end
  if timer and not timer:is_closing() then timer:close() end
  pipe, timer, buf = nil, nil, nil
  agents, ids, status = {}, {}, ''
end

--- Closes the current window, or swaps the list out when it is the last one.
H.close_window = function()
  if #vim.api.nvim_tabpage_list_wins(0) > 1 then return vim.api.nvim_win_close(0, false) end
  if vim.fn.bufnr('#') ~= -1 then return vim.cmd.buffer('#') end
  vim.cmd.enew()
end

--- Shows `agent`'s terminal. An agent in another nvim is shown there, and
--- this nvim's UI `:connect`s over to it.
--- @param agent huey.Agent
H.jump = function(agent)
  if agent.pid == vim.fn.getpid() then
    local win = vim.fn.win_findbuf(agent.buf)[1]
    if win then
      H.close_window()
      return vim.api.nvim_set_current_win(win)
    end
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then H.close_window() end
    local ok, err = pcall(vim.cmd.buffer, agent.buf)
    if not ok then vim.notify('huey: ' .. err, vim.log.levels.WARN) end
    return
  end

  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', agent.server, { rpc = true })
  if not ok or chan == 0 then
    return vim.notify('huey: cannot reach ' .. (agent.server or '?'), vim.log.levels.WARN)
  end
  pcall(vim.rpcrequest, chan, 'nvim_exec_lua', 'vim.cmd.buffer(...)', { agent.buf })
  pcall(vim.fn.chanclose, chan)

  H.close_window()
  local cok, cerr = pcall(vim.cmd.connect, agent.server)
  if not cok then vim.notify('huey: ' .. cerr, vim.log.levels.WARN) end
end

--- @param b integer
H.create = function(b)
  vim.api.nvim_buf_set_name(b, 'huey://agents')
  vim.bo[b].bufhidden = 'wipe'
  vim.bo[b].modifiable = false
  vim.bo[b].undolevels = -1
  vim.bo[b].filetype = 'hueyagents'

  local map = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = b, nowait = true, desc = desc })
  end
  map('<CR>', function()
    local id = ids[vim.api.nvim_win_get_cursor(0)[1]]
    if id and agents[id] then H.jump(agents[id]) end
  end, 'Jump to agent')
  map('q', H.close_window, 'Close')
  map('r', H.watch, 'Reconnect to the hub')

  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = b,
    once = true,
    desc = 'Stop watching the hub',
    callback = H.stop,
  })

  -- ages tick once a second while the list is on screen
  timer = assert(vim.uv.new_timer())
  timer:start(1000, 1000, vim.schedule_wrap(function()
    if H.alive() and #vim.fn.win_findbuf(buf) > 0 then H.render() end
  end))
end

--- Opens the list in a split at the bottom, or focuses it when already open.
Agents.open = function()
  if H.alive() then
    local win = vim.fn.win_findbuf(buf)[1]
    if win then return vim.api.nvim_set_current_win(win) end
  else
    buf = vim.api.nvim_create_buf(false, true)
    H.create(buf)
    H.watch()
  end

  vim.cmd('botright 12split')
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo[0][0].wrap = false
  vim.wo[0][0].number = false
  vim.wo[0][0].relativenumber = false
  vim.wo[0][0].signcolumn = 'no'
  vim.wo[0][0].cursorline = true
  H.render()
  if vim.api.nvim_buf_line_count(buf) > 1 then vim.api.nvim_win_set_cursor(0, { 2, 0 }) end
end

return Agents
