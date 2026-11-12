-- Connects this nvim to the hub (starting one if needed) and sends it the
-- status of every agent terminal, read from 'huey/term'.
local proto = require('huey.hub.proto')

local Client = {}
local H = {}

--- @type uv.uv_pipe_t?
local pipe
local connecting = false
local leaving = false

--- @param msg table
H.send = function(msg)
  if not pipe or pipe:is_closing() then return end
  pipe:write(proto.encode(msg))
end

--- The project name, with the jj workspace after a slash unless it is
--- `default`; the folder name outside a project.
--- @return string
H.workspace = function()
  local ok, projects = pcall(require, 'huey.projects')
  if ok then return projects.current_label() end
  return vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
end

--- The hub message for `buf`: its status, or `gone` when it has none.
--- @param buf integer
--- @return table
H.message = function(buf)
  local status = rawget(_G, 'HueyTerm') and HueyTerm.get_status(buf)
  if not status or not vim.api.nvim_buf_is_valid(buf) then
    return { t = 'gone', buf = buf }
  end
  local msg = vim.tbl_extend('force', {}, status)
  msg.t = 'status'
  msg.buf = buf
  msg.name = vim.api.nvim_buf_get_name(buf)
  msg.workspace = H.workspace()
  msg.cwd = vim.b[buf].osc7_dir or vim.fn.getcwd()
  return msg
end

--- Tell the hub about `buf`'s current status. No-op while disconnected; the
--- next connect sends everything again.
--- @param buf integer
Client.publish = function(buf) H.send(H.message(buf)) end

--- @param pipe_ uv.uv_pipe_t
H.on_connect = function(pipe_)
  pipe = pipe_
  H.send({ t = 'hello', role = 'nvim', pid = vim.fn.getpid(), server = vim.v.servername })
  local term = rawget(_G, 'HueyTerm')
  if not term then return end
  for buf in pairs(term.statuses()) do
    Client.publish(buf)
  end
end

H.on_close = function()
  pipe = nil
  if leaving then return end
  -- the hub went away (idle exit, killed); bring one back
  vim.schedule(function() Client.connect() end)
end

--- Connect to the hub, starting one when nothing answers.
Client.connect = function()
  if connecting or pipe or leaving then return end
  connecting = true
  proto.reach(function() end, H.on_close, function(p)
    connecting = false
    if not p then return vim.notify('huey: could not reach the hub', vim.log.levels.WARN) end
    H.on_connect(p)
  end)
end

Client.setup = function()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('HueyHubClient', {}),
    desc = 'Stop reconnecting to the hub while quitting',
    callback = function() leaving = true end,
  })

  Client.connect()
end

return Client
