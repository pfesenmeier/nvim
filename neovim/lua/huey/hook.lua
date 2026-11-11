-- `huey hook`: turns a Claude Code hook event (JSON on stdin) into an agent
-- status and hands it to the nvim whose terminal Claude runs in, over $NVIM.
-- This goes around the terminal because ConPTY on Windows drops OSC 7501.
-- Runs under `nvim -l`. Never prints: a hook's stdout goes to Claude.
local View = require('huey.hub.view')

local Hook = {}
local H = {}

--- First line of `text`, shortened, or nil when blank.
--- @param text any
--- @return string?
H.first_line = function(text)
  if type(text) ~= 'string' then return nil end
  local line = vim.trim(text):match('^[^\r\n]*')
  if line == '' then return nil end
  return View.fit(line, 120)
end

--- The status a hook event means, as OSC 7501 fields, or nil to send nothing.
--- @param ev table hook input
--- @return table?
H.status = function(ev)
  local name = ev.hook_event_name
  if name == 'SessionStart' then return { state = 'idle' } end
  if name == 'UserPromptSubmit' then return { state = 'working', title = H.first_line(ev.prompt) } end
  -- after a tool runs, so it also ends a wait on permission or a question
  if name == 'PostToolUse' or name == 'PostToolUseFailure' then return { state = 'working' } end
  if name == 'PermissionRequest' then
    return { state = 'blocked', kind = 'permission', msg = H.first_line(ev.tool_name) }
  end
  if name == 'PreToolUse' and ev.tool_name == 'AskUserQuestion' then
    return { state = 'blocked', kind = 'question' }
  end
  if name == 'Notification' and ev.notification_type == 'elicitation_dialog' then
    return { state = 'blocked', kind = 'question', msg = H.first_line(ev.message) }
  end
  if name == 'Stop' then return { state = 'done' } end
  if name == 'StopFailure' then
    return { state = 'error', msg = H.first_line(ev.error) or H.first_line(ev.error_details) }
  end
  if name == 'SessionEnd' then return { state = 'clear' } end
end

H.run = function()
  -- taken first, so reports from hooks started in order stay in order
  local sec, usec = vim.uv.gettimeofday()
  local at = sec * 1e6 + usec

  local server = vim.env.NVIM
  if not server or server == '' then return end

  local ok, ev = pcall(vim.json.decode, io.read('*a'), { luanil = { object = true } })
  if not ok or type(ev) ~= 'table' then return end
  local status = H.status(ev)
  if not status then return end
  status.app = 'claude-code'

  local cok, chan = pcall(vim.fn.sockconnect, 'pipe', server, { rpc = true })
  if not cok or chan == 0 then return end
  pcall(
    vim.rpcrequest,
    chan,
    'nvim_exec_lua',
    'if HueyTerm then return HueyTerm.report(...) end',
    { vim.fn.getpid(), status, at }
  )
  pcall(vim.fn.chanclose, chan)
end

--- Never fails: an error would show up in Claude as a failed hook.
Hook.run = function() pcall(H.run) end

Hook.H = H

return Hook
