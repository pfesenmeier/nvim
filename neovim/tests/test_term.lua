local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

-- Statuses come from real OSC 7501 sequences a real terminal job prints, so the
-- TermRequest/TermClose wiring is exercised end to end.
local T = new_set({ hooks = { pre_case = child.setup, post_once = child.stop } })

--- Sets up the module and runs `cmd` in a terminal buffer. `_G.closed` turns
--- true once the module's own TermClose handler has run.
--- @param cmd string shell command
local start_term = function(cmd)
  child.lua(
    [[
    require('huey.term').setup()
    _G.job = vim.fn.jobstart({ 'sh', '-c', ... }, { term = true })
    _G.term_buf = vim.api.nvim_get_current_buf()
    -- registered after the module's, so it runs after it
    vim.api.nvim_create_autocmd('TermClose', {
      callback = function() _G.closed = true end,
    })
  ]],
    { cmd }
  )
end

--- A shell `printf` that sends one OSC 7501 record.
--- @param body string e.g. 'state=working:progress=50'
local osc = function(body) return ([[printf '\033]7501;%s\033\\']]):format(body) end

local icon = function() return child.lua_get('HueyTerm.get_icon(_G.term_buf)') end
local status = function() return child.lua_get('HueyTerm.get_status(_G.term_buf)') end
local wait_icon = function(want)
  local expr = ('HueyTerm.get_icon(_G.term_buf) == %s'):format(vim.inspect(want))
  eq(child.wait_for(expr), true)
end
--- Lets the script past its next `read`.
local advance = function() child.lua([[vim.fn.chansend(_G.job, '\n')]]) end

T['shows the tabline icon, and clears it on state=clear'] = function()
  start_term(osc('state=working') .. '; read x; ' .. osc('state=clear') .. '; sleep 30')
  wait_icon('∿')
  advance()
  wait_icon(nil)
end

T['shows progress as a moon that is never full'] = new_set({
  parametrize = { { '0', '○' }, { '50', '◑' }, { '100', '◕' } },
}, {
  test = function(progress, shown)
    start_term(osc('state=working:progress=' .. progress) .. '; sleep 30')
    wait_icon(shown)
  end,
})

--- Prints status `body`, then exits once advanced.
--- @param body string
--- @param shown string icon expected while the process lives
local exit_after = function(body, shown)
  start_term(osc(body) .. '; read x')
  wait_icon(shown)
  advance()
  eq(child.wait_for('_G.closed'), true)
end

T['TermClose drops a status a dead process cannot hold'] = new_set({
  parametrize = {
    { 'state=working', '∿' },
    { 'state=working:progress=50', '◑' },
    { 'state=blocked:kind=permission', '⏸' },
    { 'state=idle', '·' },
  },
}, {
  test = function(body, shown)
    exit_after(body, shown)
    eq(icon(), vim.NIL)
  end,
})

T['TermClose keeps an outcome'] = new_set({
  parametrize = { { 'state=error', '⊘' }, { 'state=done', '●' } },
}, {
  test = function(body, shown)
    exit_after(body, shown)
    eq(icon(), shown)
  end,
})

T['decodes title and msg'] = function()
  local title = vim.base64.encode('Fix the parser')
  local msg = vim.base64.encode('Run rm -rf build?')
  start_term(
    osc(('state=blocked:app=claude-code:kind=permission:title=%s:msg=%s'):format(title, msg))
      .. '; sleep 30'
  )
  wait_icon('⏸')
  local s = status()
  eq({ s.state, s.kind, s.app, s.title, s.msg }, {
    'blocked',
    'permission',
    'claude-code',
    'Fix the parser',
    'Run rm -rf build?',
  })
end

T['keeps the last title when a record has none'] = function()
  local title = vim.base64.encode('Fix the parser')
  start_term(
    osc('state=working:title=' .. title) .. '; read x; ' .. osc('state=idle') .. '; sleep 30'
  )
  wait_icon('∿')
  advance()
  wait_icon('·')
  eq(status().title, 'Fix the parser')
end

T['ignores sub-records'] = function()
  start_term(osc('state=blocked:id=sub1') .. '; ' .. osc('state=working') .. '; sleep 30')
  wait_icon('∿')
end

T['answers the probe'] = function()
  local out = child.lua_get('vim.fn.tempname()')
  -- raw so the reply arrives without waiting for a newline
  start_term(
    ([[stty raw -echo; printf '\033]7501;?\033\\'; head -c 10 > %s; sleep 30]]):format(out)
  )
  eq(child.wait_for(('vim.uv.fs_stat(%q) and vim.uv.fs_stat(%q).size == 10'):format(out, out)), true)
  eq(child.lua_get('vim.fn.readblob(...)', { out }), '\27]7501;?\27\\')
end

local is_bot = function() return child.lua_get('HueyTerm.is_bot(_G.term_buf)') end

T['keeps a status when the buffer is visited'] = function()
  start_term(osc('state=done') .. '; sleep 30')
  wait_icon('●')
  child.cmd('enew')
  child.cmd('buffer ' .. child.lua_get('_G.term_buf'))
  eq(icon(), '●')
end

T['stays a bot after state=clear'] = function()
  start_term(osc('state=working') .. '; read x; ' .. osc('state=clear') .. '; sleep 30')
  wait_icon('∿')
  advance()
  wait_icon(nil)
  eq(is_bot(), true)
end

T['a plain terminal is no bot'] = function()
  start_term('sleep 30')
  eq(is_bot(), false)
end

T['stops being a bot when its process exits'] = function()
  start_term(osc('state=done') .. '; read x')
  wait_icon('●')
  advance()
  eq(child.wait_for('_G.closed'), true)
  eq(is_bot(), false)
end

T['forgets a wiped buffer'] = function()
  start_term(osc('state=working') .. '; sleep 30')
  wait_icon('∿')
  child.lua('_G.wiped = _G.term_buf; vim.cmd.bwipeout({ bang = true })')
  eq(child.lua_get('HueyTerm.get_icon(_G.wiped)'), vim.NIL)
end

-- The outer terminal hears one status for all the terminals: the most urgent.

--- Records what is sent to the outer terminal in `_G.sent`.
local record_sent = function()
  child.lua([[
    _G.sent = {}
    vim.api.nvim_ui_send = function(s) table.insert(_G.sent, s) end
  ]])
end
local sent = function() return child.lua_get('_G.sent') end

--- Runs `cmd` in a second terminal buffer, kept in `_G.other_buf`, and waits
--- for it to show `shown`.
local start_other = function(cmd, shown)
  child.lua(
    [[
    vim.cmd.enew()
    vim.fn.jobstart({ 'sh', '-c', ... }, { term = true })
    _G.other_buf = vim.api.nvim_get_current_buf()
  ]],
    { cmd }
  )
  eq(child.wait_for(('HueyTerm.get_icon(_G.other_buf) == %q'):format(shown)), true)
end

T['the outer terminal'] = new_set()

T['the outer terminal']['hears working over done'] = function()
  record_sent()
  start_term(osc('state=working') .. '; sleep 30')
  wait_icon('∿')
  start_other(osc('state=done') .. '; sleep 30', '●')
  eq(sent(), { '\27]7501;state=working\27\\' })
end

T['the outer terminal']['hears blocked over working'] = function()
  record_sent()
  start_term(osc('state=working:progress=50') .. '; sleep 30')
  wait_icon('◑')
  start_other(osc('state=blocked:kind=permission') .. '; sleep 30', '⏸')
  eq(sent(), {
    '\27]7501;state=working:progress=50\27\\',
    '\27]7501;state=blocked:kind=permission\27\\',
  })
end

T['the outer terminal']['hears done once nothing is still working'] = function()
  record_sent()
  start_term(osc('state=working') .. '; read x; ' .. osc('state=done') .. '; sleep 30')
  wait_icon('∿')
  start_other(osc('state=done') .. '; sleep 30', '●')
  advance()
  wait_icon('●')
  eq(sent(), { '\27]7501;state=working\27\\', '\27]7501;state=done\27\\' })
end

T['the outer terminal']['hears a clear once no terminal has a status'] = function()
  record_sent()
  start_term(osc('state=working') .. '; read x; ' .. osc('state=clear') .. '; sleep 30')
  wait_icon('∿')
  advance()
  wait_icon(nil)
  eq(sent(), { '\27]7501;state=working\27\\', '\27]7501;state=clear\27\\' })
end

T['the outer terminal']['hears the title and why it is blocked'] = function()
  record_sent()
  local title = vim.base64.encode('Fix the parser')
  local msg = vim.base64.encode('Run rm?')
  start_term(
    osc(('state=blocked:app=claude-code:kind=permission:title=%s:msg=%s'):format(title, msg))
      .. '; sleep 30'
  )
  wait_icon('⏸')
  eq(sent(), {
    ('\27]7501;state=blocked:kind=permission:app=claude-code:title=%s:msg=%s\27\\'):format(title, msg),
  })
end

T['the outer terminal']['hears the next most urgent once a terminal is wiped'] = function()
  record_sent()
  start_term(osc('state=working') .. '; sleep 30')
  wait_icon('∿')
  start_other(osc('state=blocked') .. '; sleep 30', '⏸')
  child.cmd('bwipeout! ' .. child.lua_get('_G.other_buf'))
  eq(sent(), {
    '\27]7501;state=working\27\\',
    '\27]7501;state=blocked\27\\',
    '\27]7501;state=working\27\\',
  })
end

-- Statuses from Claude Code hooks, which reach nvim over RPC rather than
-- through the terminal (see 'huey/hook').

local huey = vim.fs.normalize(vim.fn.fnamemodify('../bin/huey', ':p'))
local nvim = vim.fs.normalize(vim.v.progpath)

--- A shell command that runs `huey hook` with `event` on stdin, as Claude Code
--- would from inside the terminal.
--- @param event table hook input
--- @return string
local hook = function(event)
  local file = vim.fs.normalize(vim.fn.tempname())
  vim.fn.writefile({ vim.json.encode(event) }, file)
  return ("'%s' -l '%s' hook < '%s'"):format(nvim, huey, file)
end

T['takes a status from a Claude Code hook'] = new_set({
  parametrize = {
    { { hook_event_name = 'SessionStart' }, '·', {} },
    {
      { hook_event_name = 'UserPromptSubmit', prompt = '  Fix the parser\nand the tests' },
      '∿',
      { title = 'Fix the parser' },
    },
    {
      { hook_event_name = 'PermissionRequest', tool_name = 'Bash', tool_input = {} },
      '⏸',
      { kind = 'permission', msg = 'Bash' },
    },
    { { hook_event_name = 'PreToolUse', tool_name = 'AskUserQuestion' }, '⏸', { kind = 'question' } },
    { { hook_event_name = 'Stop' }, '●', {} },
    { { hook_event_name = 'StopFailure', error = 'rate_limit' }, '⊘', { msg = 'rate_limit' } },
  },
}, {
  test = function(event, shown, fields)
    start_term(hook(event) .. '; sleep 30')
    wait_icon(shown)
    local s = status()
    eq(s.app, 'claude-code')
    for key, value in pairs(fields) do
      eq(s[key], value)
    end
  end,
})

T['a hook event that means nothing sends nothing'] = function()
  local done = vim.fs.normalize(vim.fn.tempname())
  start_term(
    hook({ hook_event_name = 'PreToolUse', tool_name = 'Bash' }) .. ("; : > '%s'; sleep 30"):format(done)
  )
  eq(child.wait_for(('vim.uv.fs_stat(%q) ~= nil'):format(done)), true)
  eq(is_bot(), false)
end

T['drops a hook report older than the last one'] = function()
  start_term('sleep 30')
  child.lua([[
    local pid = vim.fn.jobpid(_G.job)
    HueyTerm.report(pid, { state = 'done' }, 2)
    _G.applied = HueyTerm.report(pid, { state = 'working' }, 1)
  ]])
  eq(child.lua_get('_G.applied'), false)
  eq(icon(), '●')
end

T['ignores a hook report from outside every terminal'] = function()
  start_term('sleep 30')
  eq(child.lua_get([[HueyTerm.report(vim.fn.getpid(), { state = 'done' }, 1)]]), false)
  eq(icon(), vim.NIL)
end

T['ignores hook reports once the terminal sends OSC 7501 itself'] = function()
  if vim.fn.has('win32') == 1 then MiniTest.skip('ConPTY drops OSC 7501') end
  start_term(osc('state=working') .. '; sleep 30')
  wait_icon('∿')
  eq(child.lua_get([[HueyTerm.report(vim.fn.jobpid(_G.job), { state = 'done' }, 1)]]), false)
  eq(icon(), '∿')
end

return T
