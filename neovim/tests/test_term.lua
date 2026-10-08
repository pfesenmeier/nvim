local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

-- Statuses come from real OSC 9;4 sequences a real terminal job prints, so the
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

local icon = function() return child.lua_get('HueyTerm.get_icon(_G.term_buf)') end
local wait_icon = function(want)
  local expr = ('HueyTerm.get_icon(_G.term_buf) == %s'):format(vim.inspect(want))
  eq(child.wait_for(expr), true)
end
--- Lets the script past its next `read`.
local advance = function() child.lua([[vim.fn.chansend(_G.job, '\n')]]) end

T['shows the tabline icon, and clears it on state 0'] = function()
  start_term([[printf '\033]9;4;3\007'; read x; printf '\033]9;4;0\007'; sleep 30]])
  wait_icon('∿')
  advance()
  wait_icon(nil)
end

--- Prints status `seq`, then exits once advanced.
--- @param seq string e.g. '3' or '1;50'
--- @param shown string icon expected while the process lives
local exit_after = function(seq, shown)
  start_term(([[printf '\033]9;4;%s\007'; read x]]):format(seq))
  wait_icon(shown)
  advance()
  eq(child.wait_for('_G.closed'), true)
end

T['TermClose drops a status a dead process cannot hold'] = new_set({
  parametrize = { { '3', '∿' }, { '1;50', '◑' }, { '4', '⏸' } },
}, {
  test = function(seq, shown)
    exit_after(seq, shown)
    eq(icon(), vim.NIL)
  end,
})

T['TermClose keeps an outcome until visited'] = new_set({
  parametrize = { { '2', '⊘' }, { '1;100', '●' } },
}, {
  test = function(seq, shown)
    exit_after(seq, shown)
    eq(icon(), shown)
  end,
})

T['forgets a wiped buffer'] = function()
  start_term([[printf '\033]9;4;3\007'; sleep 30]])
  wait_icon('∿')
  child.lua('_G.wiped = _G.term_buf; vim.cmd.bwipeout({ bang = true })')
  eq(child.lua_get('HueyTerm.get_icon(_G.wiped)'), vim.NIL)
end

return T
