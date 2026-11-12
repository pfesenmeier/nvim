-- Shared by `huey tui`, `huey hook` and the explorer: keeps a table of agents in
-- step with hub messages, and lays out one line per agent.
-- Runs under `nvim -l` too, so it only uses `vim.api` string helpers and `vim.fn`.
local proto = require('huey.hub.proto')

local View = {}

--- @param secs integer
--- @return string
View.ago = function(secs)
  secs = math.max(0, secs)
  if secs < 60 then return secs .. 's' end
  if secs < 3600 then return math.floor(secs / 60) .. 'm' end
  if secs < 86400 then return math.floor(secs / 3600) .. 'h' end
  return math.floor(secs / 86400) .. 'd'
end

--- Cuts `s` to `width` display cells.
--- @param s string
--- @param width integer
--- @return string
View.fit = function(s, width)
  if width <= 0 then return '' end
  if vim.api.nvim_strwidth(s) <= width then return s end
  local out = vim.fn.strcharpart(s, 0, width - 1)
  while vim.api.nvim_strwidth(out) > width - 1 do
    out = vim.fn.strcharpart(out, 0, vim.fn.strchars(out) - 1)
  end
  return out .. '…'
end

--- @param s string
--- @param width integer
--- @return string
View.pad = function(s, width)
  s = View.fit(s, width)
  return s .. string.rep(' ', width - vim.api.nvim_strwidth(s))
end

--- Applies a hub message to `agents` in place.
--- @param agents table<string, huey.Agent>
--- @param msg table
View.apply = function(agents, msg)
  if msg.t == 'snapshot' then
    for id in pairs(agents) do
      agents[id] = nil
    end
    for _, a in ipairs(msg.agents or {}) do
      agents[a.id] = a
    end
  elseif msg.t == 'update' then
    agents[msg.agent.id] = msg.agent
  elseif msg.t == 'remove' then
    agents[msg.id] = nil
  end
end

--- Agents in display order: by workspace, then oldest first.
--- @param agents table<string, huey.Agent>
--- @return huey.Agent[]
View.rows = function(agents)
  local rows = vim.tbl_values(agents)
  table.sort(rows, function(a, b)
    if a.workspace ~= b.workspace then return (a.workspace or '') < (b.workspace or '') end
    if a.started ~= b.started then return (a.started or 0) < (b.started or 0) end
    return a.id < b.id
  end)
  return rows
end

--- What the agent is working on, or failing that, its terminal's name.
--- @param agent huey.Agent
--- @return string
View.summary = function(agent)
  local text = agent.title or agent.msg
  if not text or text == '' then text = vim.fs.basename(agent.name or '') end
  return (text:gsub('[%c]', ' '))
end

--- @return string
View.header = function()
  return ('   %s  %s  %s  %s  %s'):format(
    View.pad('STATE', 20),
    View.pad('WORKSPACE', 14),
    View.pad('AGE', 4),
    View.pad('FOR', 4),
    'SUMMARY'
  )
end

--- Highlight group for each state.
View.state_hl = {
  working = 'DiagnosticInfo',
  blocked = 'DiagnosticWarn',
  error = 'DiagnosticError',
  done = 'DiagnosticOk',
  idle = 'Comment',
}

--- The state, with why it is blocked or how far along it is, e.g.
--- `blocked(permission)` or `working 40%`.
--- @param agent { state: string, kind: string?, progress: integer? }
--- @return string
View.state = function(agent)
  local state = agent.state .. (agent.kind and ('(' .. agent.kind .. ')') or '')
  if agent.state == 'working' and agent.progress then
    state = state .. ' ' .. agent.progress .. '%'
  end
  return state
end

--- One agent's line, and the byte its state column ends at, for highlighting.
--- @param agent huey.Agent
--- @param now integer epoch seconds
--- @return string line
--- @return integer state_end
View.line = function(agent, now)
  local head = (' %s %s'):format(proto.icon(agent.state, agent.progress) or ' ', View.pad(View.state(agent), 20))
  local rest = ('  %s  %s  %s  '):format(
    View.pad(agent.workspace or '?', 14),
    View.pad(View.ago(now - (agent.started or now)), 4),
    View.pad(View.ago(now - (agent.changed or now)), 4)
  )
  return head .. rest .. View.summary(agent), #head
end

return View
