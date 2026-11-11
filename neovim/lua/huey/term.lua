-- module for reading agent status (OSC 7501) from terminal buffers, showing it
-- in the bufferline, forwarding it to the outer terminal, and publishing it to
-- the hub (see 'huey/hub')
local HueyTerm = {}
local H = {}

local proto = require('huey.hub.proto')

--  OSC 7501: ESC ] 7501 ; key=value:key=value ESC \
--  ┌──────────┬───────────────────────────────────────────────────────┐
--  │ key      │ value                                                 │
--  ├──────────┼───────────────────────────────────────────────────────┤
--  │ state    │ idle, working, done, blocked, error, or clear         │
--  │ kind     │ permission, question, auth (with blocked)             │
--  │ progress │ 0-100 (with working or blocked)                       │
--  │ title    │ base64, what it is working on                         │
--  │ msg      │ base64, why it is blocked                             │
--  │ app      │ e.g. claude-code                                      │
--  │ id       │ a sub-record (e.g. a sub-agent), ignored here         │
--  └──────────┴───────────────────────────────────────────────────────┘
--  A program sends `ESC ] 7501 ; ?` first and only reports if the terminal
--  answers, so every terminal buffer answers it.

--- @class huey.Status
--- @field state string
--- @field kind? string
--- @field progress? integer
--- @field title? string
--- @field msg? string
--- @field app? string
--- @field started integer epoch seconds of the first status
--- @field changed integer epoch seconds the state last changed

--- @type table<integer, huey.Status> bufnr => status
local bufstatuses = {}

--- @type table<integer, integer> bufnr => when it first reported, kept across clears
local first_seen = {}

--- @type table<integer, true> terminals that have reported and are still running
local bots = {}

local probe_reply = '\27]7501;?\27\\'

--- @param value string
--- @return string?
H.decode = function(value)
  local ok, out = pcall(vim.base64.decode, value)
  if ok then return out end
end

--- Parses an OSC 7501 sequence.
--- @param sequence string
--- @return { probe: true }|{ state: string, kind?: string, progress?: integer, title?: string, msg?: string, app?: string, id?: string }|nil
H.parse_status = function(sequence)
  local body = sequence:match('^\27%]7501;(.*)$')
  if not body then return nil end
  if body:sub(1, 1) == '?' then return { probe = true } end

  local fields = {}
  for pair in vim.gsplit(body, ':', { plain = true }) do
    local key, value = pair:match('^([^=]+)=(.*)$')
    if key then fields[key] = value end
  end
  if not fields.state or fields.state == '' then return nil end

  return {
    state = fields.state,
    kind = fields.kind,
    progress = tonumber(fields.progress),
    title = fields.title and H.decode(fields.title),
    msg = fields.msg and H.decode(fields.msg),
    app = fields.app,
    id = fields.id,
  }
end

--- Writes a raw OSC sequence straight to the TUI host terminal.
--- @param sequence string
--- @param terminator string? BEL or ST, as the program sent it
H.forward_raw = function(sequence, terminator)
  vim.api.nvim_ui_send(sequence .. (terminator or '\27\\'))
end

--- Emits status as Nvim's internal |Progress| event via nvim_echo,
--- for anything (statusline, other autocmds) hooking that event.
--- @param status huey.Status
--- @param title string?
--- @param source string?
H.echo_progress = function(status, title, source)
  local opts = { kind = 'progress', title = title, source = source }

  if status.state == 'working' then
    opts.status = 'running'
    opts.percent = status.progress -- omitted => indeterminate
  elseif status.state == 'done' then
    opts.status = 'success'
    opts.percent = 100
  elseif status.state == 'error' then
    opts.status = 'failed'
  else
    -- idle, blocked: no "paused" status; closest is 'cancel'
    opts.status = 'cancel'
  end

  vim.api.nvim_echo({ { title or '' } }, false, opts)
end

---@param buf integer
---@param status huey.Status
H.notify = function(buf, status)
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')

  ---@type string?, vim.log.levels?
  local msg, level

  if status.state == 'done' then
    msg, level = ' is done.', vim.log.levels.INFO
  elseif status.state == 'error' then
    msg, level = ' has errored.', vim.log.levels.ERROR
  elseif status.state == 'blocked' then
    msg = (' needs %s'):format(status.kind or 'input')
    if status.msg then msg = msg .. ': ' .. status.msg end
    level = vim.log.levels.WARN
  end

  if msg then
    msg = name .. msg
    vim.notify(msg, level)
  end

  H.echo_progress(status, msg, name)
end

--- Stores a new status for `buf`. Returns false when nothing visible changed.
--- @param buf integer
--- @param parsed table from H.parse_status
--- @return boolean
H.update = function(buf, parsed)
  local now = os.time()
  local prev = bufstatuses[buf]
  first_seen[buf] = first_seen[buf] or now

  local status = {
    state = parsed.state,
    kind = parsed.kind,
    progress = parsed.progress,
    -- keep the last summary until the program says something new
    title = parsed.title or (prev and prev.title),
    msg = parsed.msg,
    app = parsed.app,
    started = first_seen[buf],
    changed = (prev and prev.state == parsed.state) and prev.changed or now,
  }
  bufstatuses[buf] = status

  return not (prev and vim.deep_equal(prev, status))
end

---@param buf integer
---@return string|nil
HueyTerm.get_icon = function(buf)
  local status = bufstatuses[buf]
  if not status then return nil end
  return proto.icon(status.state, status.progress)
end

--- The full status of a terminal buffer, or nil when it has none.
---@param buf integer
---@return huey.Status?
HueyTerm.get_status = function(buf) return bufstatuses[buf] end

--- Every terminal buffer with a status.
---@return table<integer, huey.Status>
HueyTerm.statuses = function() return bufstatuses end

--- True for a running terminal that has reported a status, even when it has no
--- status right now (e.g. one that sent state=clear).
---@param buf number
---@return boolean
HueyTerm.is_bot = function(buf) return bots[buf] == true end

--- Tells the hub, if the client is set up. Kept lazy so tests and `nvim -l`
--- never start a hub by accident.
--- @param buf integer
H.publish = function(buf)
  local client = package.loaded['huey.hub.client']
  if client then client.publish(buf) end
end

H.create_autocmds = function()
  local gr = vim.api.nvim_create_augroup('HueyTerm', {})

  vim.api.nvim_create_autocmd({ 'TermRequest' }, {
    group = gr,
    desc = 'Track agent status from OSC 7501',
    callback = function(ev)
      local buf = ev.buf
      local parsed = H.parse_status(ev.data.sequence)
      if not buf or not parsed then return end

      if parsed.probe then
        local chan = vim.bo[buf].channel
        if chan ~= 0 then vim.api.nvim_chan_send(chan, probe_reply) end
        return
      end

      -- sub-records (e.g. sub-agents) are not shown yet
      if parsed.id then return end

      bots[buf] = true
      if parsed.state == 'clear' then
        if not bufstatuses[buf] then return end
        bufstatuses[buf] = nil
      elseif not H.update(buf, parsed) then
        return
      end

      vim.cmd.redrawtabline()
      H.forward_raw(ev.data.sequence, ev.data.terminator)
      H.publish(buf)

      local status = bufstatuses[buf]
      if status then H.notify(buf, status) end
      vim.api.nvim_exec_autocmds('User', {
        pattern = 'HueyTermStatus',
        data = { buf = buf, status = status },
      })
    end,
  })

  vim.api.nvim_create_autocmd({ 'TermClose' }, {
    group = gr,
    desc = 'Drop statuses a dead process can no longer hold',
    callback = function(ev)
      bots[ev.buf] = nil
      local status = bufstatuses[ev.buf]
      if not status then return end

      -- keep outcomes (done, error) until the buffer is wiped
      if status.state ~= 'done' and status.state ~= 'error' then
        bufstatuses[ev.buf] = nil
        vim.cmd.redrawtabline()
      end
      H.publish(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWipeout' }, {
    group = gr,
    desc = 'Forget a wiped buffer so a reused number starts clean',
    callback = function(ev)
      local had = bufstatuses[ev.buf] or bots[ev.buf]
      bufstatuses[ev.buf] = nil
      first_seen[ev.buf] = nil
      bots[ev.buf] = nil
      if had then H.publish(ev.buf) end
    end,
  })

  -- :h terminal-osc7
  vim.api.nvim_create_autocmd({ 'TermRequest' }, {
    group = gr,
    desc = 'Handles OSC 7 dir change requests',
    callback = function(ev)
      local val, n = string.gsub(ev.data.sequence, '\027]7;file://[^/]*', '')
      if n > 0 then
        -- OSC 7: dir-change
        local dir = val
        if vim.fn.isdirectory(dir) == 0 then
          vim.notify('invalid dir: ' .. dir)
          return
        end
        vim.b[ev.buf].osc7_dir = dir
        if vim.api.nvim_get_current_buf() == ev.buf then vim.cmd.lcd(dir) end
      end
    end,
  })
end

-- most urgent first
local sort_order = { blocked = 1, error = 2, working = 3, done = 4, idle = 5 }

---@param first huey.Status
---@param second huey.Status
---@return boolean
H.sort_status = function(first, second)
  local a, b = sort_order[first.state] or 6, sort_order[second.state] or 6
  if a == b and first.state == 'working' then
    return (first.progress or 0) < (second.progress or 0)
  end
  return a < b
end

--- The most urgent status across all terminals.
--- @return huey.Status|nil
HueyTerm.get_editor_icon = function()
  local values = vim.tbl_values(bufstatuses)

  table.sort(values, H.sort_status)

  return values[1]
end

HueyTerm.setup = function()
  _G.HueyTerm = HueyTerm
  H.create_autocmds()
end

return HueyTerm
