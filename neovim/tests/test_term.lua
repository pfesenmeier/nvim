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

return T
