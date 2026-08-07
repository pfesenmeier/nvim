local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local expect = helpers.expect
local new_set = MiniTest.new_set

-- Sequence parsing and URI decoding touch no editor state, so they run here
-- rather than paying for a child restart per case.
local M = require('huey.termlink')
local H = M.H

local temp_roots = {}

local new_temp_dir = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  table.insert(temp_roots, root)
  return root
end

local cleanup_temp_roots = function()
  for _, root in ipairs(temp_roots) do
    vim.fn.delete(root, 'rf')
  end
  temp_roots = {}
end

local T = new_set({ hooks = { post_case = cleanup_temp_roots } })

T['H.parse_osc8()'] = new_set()

--stylua: ignore
local osc8_cases = {
  { 'open with empty params', '\27]8;;file:///a/b.lua', '',      'file:///a/b.lua' },
  { 'open with params',       '\27]8;id=1;file:///a',  'id=1',   'file:///a' },
  { 'close',                  '\27]8;;',               '',       '' },
  { 'uri containing a semicolon', '\27]8;;file:///a;b', '',      'file:///a;b' },
  -- Must not swallow the sequences 'huey/term.lua' handles.
  { 'osc 7 dir change',       '\27]7;file://host/tmp', nil,      nil },
  { 'osc 9;4 progress',       '\27]9;4;1;50',          nil,      nil },
  { 'not a sequence',         'plain text',            nil,      nil },
  { 'truncated',              '\27]8;',                nil,      nil },
}

for _, case in ipairs(osc8_cases) do
  T['H.parse_osc8()'][case[1]] = function()
    local params, uri = H.parse_osc8(case[2])
    eq(params, case[3])
    eq(uri, case[4])
  end
end

T['H.uri_to_target()'] = new_set()

--stylua: ignore
local uri_cases = {
  { 'plain file uri',        'file:///a/b.lua',           { path = '/a/b.lua' } },
  { 'percent-encoded space', 'file:///a/b%20c.lua',       { path = '/a/b c.lua' } },
  { 'percent-encoded utf8',  'file:///a/caf%C3%A9.lua',   { path = '/a/caf\u{e9}.lua' } },
  { 'localhost authority',   'file://localhost/a/b.lua',  { path = '/a/b.lua' } },
  { 'line fragment',         'file:///a/b.lua#L12',       { path = '/a/b.lua', lnum = 12 } },
  { 'bare number fragment',  'file:///a/b.lua#34',        { path = '/a/b.lua', lnum = 34 } },
  { 'line range fragment',   'file:///a/b.lua#L12-L20',   { path = '/a/b.lua', lnum = 12 } },
  -- Not a local file: handed to `vim.ui.open` rather than `:edit`.
  { 'https url',             'https://example.com/x',     { url = 'https://example.com/x' } },
  { 'remote file authority', 'file://other/a/b.lua',      { url = 'file://other/a/b.lua' } },
  { 'not a uri',             'just text',                 nil },
}

for _, case in ipairs(uri_cases) do
  T['H.uri_to_target()'][case[1]] = function() eq(H.uri_to_target(case[2]), case[3]) end
end

T['H.latest_frame()'] = new_set()

local q = function(...)
  local out = {}
  for _, pair in ipairs({ ... }) do
    table.insert(out, { row = pair[1], uri = pair[2] })
  end
  return out
end

local uris = function(links)
  return vim.tbl_map(function(l) return l.row .. ':' .. l.uri end, links)
end

T['H.latest_frame()']['keeps a single frame whole'] = function()
  -- Distinct links drawn top-down in one frame: all of them are real.
  eq(
    uris(H.latest_frame(q({ 1, 'a' }, { 4, 'b' }, { 9, 'c' }))),
    { '1:a', '4:b', '9:c' }
  )
end

T['H.latest_frame()']['keeps two mentions of one file in a frame'] = function()
  -- Same URI twice at different rows is ambiguous with a repaint, so only the
  -- later survives -- a lost click, never a wrong file.
  eq(uris(H.latest_frame(q({ 1, 'a' }, { 5, 'a' }))), { '5:a' })
end

T['H.latest_frame()']['drops frames before drawing restarted'] = function()
  -- Row going backwards means a new frame began.
  eq(uris(H.latest_frame(q({ 3, 'a' }, { 8, 'b' }, { 1, 'a' }, { 6, 'b' }))), {
    '1:a',
    '6:b',
  })
end

T['H.latest_frame()']['keeps only the last position of a link redrawn lower'] = function()
  -- The case that broke in practice: a streaming frame redraws the same link a
  -- row further down each time, so rows never decrease and only the last
  -- position matches the synced buffer.
  eq(
    uris(H.latest_frame(q({ 0, 'a' }, { 1, 'a' }, { 2, 'a' }, { 3, 'a' }))),
    { '3:a' }
  )
end

T['H.latest_frame()']['handles an empty batch'] = function()
  eq(H.latest_frame({}), {})
end

-- Terminal behaviour needs a real job, a real screen and real extmarks.
T['terminal'] =
  new_set({ hooks = { pre_case = child.setup, post_once = child.stop } })

--- Loads the module in the child and runs `cmd` in a terminal buffer.
--- @param cmd string shell command, single-quoted in the child
local start_term = function(cmd)
  child.lua(
    [[
    -- `plugin/` is not on the child's 'runtimepath', so require the module.
    _G.tl = require('huey.termlink')
    _G.tl.setup({ notify = false })
    vim.fn.jobstart({ 'sh', '-c', ... }, { term = true })
    _G.term_buf = vim.api.nvim_get_current_buf()
    _G.term_win = vim.api.nvim_get_current_win()
  ]],
    { cmd }
  )
end

local n_links = function()
  return child.lua_get('vim.tbl_count(_G.tl.H.links[_G.term_buf] or {})')
end

--- Blocks until `pattern` shows up on the terminal's first line *and* the
--- queued links for it have been placed. Nvim syncs terminal text on a refresh
--- timer, so both the text and the extmarks land after the TermRequest that
--- reported them -- waiting on either alone races the other.
--- @param pattern string Lua pattern, escaped for embedding in child code
--- @param n_expected integer links expected once flushing settles
local wait_for_links = function(pattern, n_expected)
  local text =
    [[(vim.api.nvim_buf_get_lines(_G.term_buf, 0, 1, false)[1] or ''):find('%s')]]
  expect.equality(child.wait_for(text:format(pattern)), true)

  local placed = 'vim.tbl_count(_G.tl.H.links[_G.term_buf] or {}) >= ' .. n_expected
  expect.equality(child.wait_for(placed), true)
end

T['terminal']['registers a link over exactly the link text'] = function()
  start_term(
    [[printf 'hello \033]8;;file:///tmp/x.lua\007LINK\033]8;;\007 world\n'; sleep 5]]
  )
  wait_for_links('hello LINK world', 1)

  local mark = child.lua_get([[
    vim.api.nvim_buf_get_extmarks(_G.term_buf, _G.tl.H.ns, 0, -1, { details = true })[1]
  ]])
  eq({ mark[2], mark[3], mark[4].end_row, mark[4].end_col }, { 0, 6, 0, 10 })

  -- Every byte of 'LINK', and nothing on either side of it.
  for col = 6, 9 do
    eq(
      child.lua_get('_G.tl.H.link_at(_G.term_buf, 0, ' .. col .. ')'),
      'file:///tmp/x.lua'
    )
  end
  eq(child.lua_get('_G.tl.H.link_at(_G.term_buf, 0, 5)'), vim.NIL)
  eq(child.lua_get('_G.tl.H.link_at(_G.term_buf, 0, 11)'), vim.NIL)
end

T['terminal']['keeps the newer link when the screen is repainted'] = function()
  start_term(table.concat({
    [[printf '\033[?1049h\033[2J\033[H']],
    [[printf 'frame1 \033]8;;file:///tmp/a.lua\007a.lua\033]8;;\007 end\n']],
    'sleep 0.4',
    [[printf '\033[2J\033[Hframe2 \033]8;;file:///tmp/b.lua\007b.lua\033]8;;\007 end\n']],
    'sleep 5',
  }, '; '))

  -- Waiting on a link *count* would race: frame 1's link also makes the count
  -- 1, so the assertion below could run before frame 2's link is placed.
  expect.equality(
    child.wait_for([[_G.tl.H.link_at(_G.term_buf, 0, 7) == 'file:///tmp/b.lua']]),
    true
  )

  -- The repaint overwrote the same columns, which leaves the first frame's
  -- extmark range intact -- so without purging, this position would still
  -- resolve to a.lua while sitting on b.lua's text.
  eq(n_links(), 1)
end

T['terminal']['survives a repaint that redraws identical text'] = function()
  -- Nvim re-syncs terminal lines on every refresh even when nothing visibly
  -- changed, and a settled line is never re-emitted with its OSC 8. Treating a
  -- rewrite as invalidation made links die seconds after being drawn.
  start_term(table.concat({
    [[printf '\033[?1049h\033[2J\033[H']],
    [[printf 'see \033]8;;file:///tmp/keep.lua\007keep.lua\033]8;;\007 end\n']],
    'sleep 0.4',
    -- Same visible text, redrawn without the hyperlink escapes.
    [[printf '\033[2J\033[Hsee keep.lua end\n']],
    'sleep 5',
  }, '; '))

  wait_for_links('see keep%.lua end', 1)
  child.lua('vim.wait(300)')

  eq(child.lua_get('_G.tl.H.link_at(_G.term_buf, 0, 4)'), 'file:///tmp/keep.lua')
end

T['terminal']['opens the file in the terminal window and keeps the terminal'] = function()
  local path = new_temp_dir() .. '/target.lua'
  vim.fn.writefile({ 'one', 'two', 'three' }, path)

  start_term(
    ([[printf 'see \033]8;;file://%s#L3\007target.lua\033]8;;\007\n'; sleep 5]]):format(
      path
    )
  )
  wait_for_links('see target%.lua', 1)

  local n_wins_before = child.lua_get('#vim.api.nvim_tabpage_list_wins(0)')
  child.lua('_G.tl.H.act(_G.term_win, 0, 4)')

  -- Same window, no split.
  eq(child.lua_get('vim.api.nvim_get_current_win()'), child.lua_get('_G.term_win'))
  eq(child.lua_get('#vim.api.nvim_tabpage_list_wins(0)'), n_wins_before)
  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), path)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)[1]'), 3)

  -- The terminal was displaced, not destroyed: still a live terminal buffer
  -- with its links, and reachable again.
  eq(child.lua_get('vim.api.nvim_buf_is_valid(_G.term_buf)'), true)
  eq(child.lua_get('vim.bo[_G.term_buf].buftype'), 'terminal')
  eq(n_links(), 1)

  child.cmd('normal! \15') -- <C-o>
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), child.lua_get('_G.term_buf'))
end

T['terminal']['clamps a fragment line past the end of the file'] = function()
  local path = new_temp_dir() .. '/short.lua'
  vim.fn.writefile({ 'only line' }, path)

  start_term(
    ([[printf 'see \033]8;;file://%s#L99\007short.lua\033]8;;\007\n'; sleep 5]]):format(
      path
    )
  )
  wait_for_links('see short%.lua', 1)

  child.lua('_G.tl.H.act(_G.term_win, 0, 4)')

  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), path)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)[1]'), 1)
end

T['terminal']['a plain left click on a link opens it'] = function()
  local path = new_temp_dir() .. '/clicked.lua'
  vim.fn.writefile({ 'one', 'two' }, path)

  start_term(
    ([[printf 'see \033]8;;file://%s\007clicked.lua\033]8;;\007 tail\n'; sleep 5]]):format(
      path
    )
  )
  wait_for_links('see clicked%.lua tail', 1)

  -- Screen row 0, column 6 -- inside 'clicked.lua', which starts at byte 4.
  child.lua("vim.api.nvim_input_mouse('left', 'press', '', 0, 0, 6)")
  child.lua('vim.wait(200)')

  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), path)
end

T['terminal']['ctrl+click opens from the release alone'] = function()
  -- Windows Terminal does not forward the Ctrl+click *press* to Nvim, only the
  -- drag and release, so binding the press alone leaves Ctrl+click dead there.
  local path = new_temp_dir() .. '/ctrl.lua'
  vim.fn.writefile({ 'one', 'two' }, path)

  start_term(
    ([[printf 'see \033]8;;file://%s\007ctrl.lua\033]8;;\007 tail\n'; sleep 5]]):format(
      path
    )
  )
  wait_for_links('see ctrl%.lua tail', 1)

  -- Release only: no press is delivered first.
  child.lua("vim.api.nvim_input_mouse('left', 'release', 'c', 0, 0, 6)")
  child.lua('vim.wait(200)')

  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), path)
end

T['terminal']['a plain left click off a link falls through'] = function()
  start_term(
    [[printf 'see \033]8;;file:///tmp/nope.lua\007nope.lua\033]8;;\007 tail\n'; sleep 5]]
  )
  wait_for_links('see nope%.lua tail', 1)

  -- Column 1 is inside 'see', outside the link: the click must behave normally
  -- rather than being swallowed, and must not open anything.
  child.lua("vim.api.nvim_input_mouse('left', 'press', '', 0, 0, 1)")
  child.lua('vim.wait(200)')

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), child.lua_get('_G.term_buf'))
end

T['terminal']['never anchors a link to unrelated text while scrolling'] = function()
  -- A TUI re-emits its links on every repaint. Flushing on a fixed delay
  -- instead of on the buffer sync anchored those batches a frame late, landing
  -- marks on whatever had scrolled into those coordinates -- so a click could
  -- open a file that was nowhere near the text clicked.
  -- Alternate screen, as Claude Code uses: each frame rewrites every row, so a
  -- row that held the link now holds filler. Frames are emitted back to back
  -- with no pause, so several land before Nvim syncs the buffer once.
  local frames = { [[printf '\033[?1049h']] }
  for i = 1, 12 do
    local before = string.rep([[printf 'FILLER-ROW-XXXXXXXXXXXXXXXXXX\n'; ]], i - 1)
    table.insert(
      frames,
      [[printf '\033[2J\033[H'; ]]
        .. before
        .. [[printf 'see \033]8;;file:///tmp/moving.lua\007moving.lua\033]8;;\007 tail\n']]
        .. [[; printf 'FILLER-ROW-XXXXXXXXXXXXXXXXXX\nFILLER-ROW-XXXXXXXXXXXXXXXXXX\n']]
    )
  end
  table.insert(frames, 'sleep 5')
  start_term(table.concat(frames, '; '))

  -- The link ends up on a different row each frame, so wait on the whole
  -- buffer rather than line 0.
  expect.equality(
    child.wait_for(
      [[table.concat(vim.api.nvim_buf_get_lines(_G.term_buf, 0, -1, false), '\n'):find('see moving%.lua tail')]]
    ),
    true
  )
  expect.equality(
    child.wait_for('vim.tbl_count(_G.tl.H.links[_G.term_buf] or {}) > 0'),
    true
  )
  child.lua('vim.wait(400)')

  -- Every surviving mark must sit exactly on its own link text.
  local bad = child.lua_get([[(function()
    local m = require('huey.termlink')
    local out = {}
    for _, mk in ipairs(vim.api.nvim_buf_get_extmarks(_G.term_buf, m.H.ns, 0, -1, { details = true })) do
      local txt = table.concat(vim.api.nvim_buf_get_text(_G.term_buf, mk[2], mk[3], mk[4].end_row, mk[4].end_col, {}), '')
      if txt ~= 'moving.lua' then table.insert(out, string.format('r%d c%d..%d %q', mk[2], mk[3], mk[4].end_col, txt)) end
    end
    return out
  end)()]])

  eq(bad, {})
end

T['terminal']['maps the trigger keys and exports FORCE_HYPERLINK'] = function()
  start_term('sleep 5')

  eq(child.lua_get('vim.env.FORCE_HYPERLINK'), '1')
  eq(child.lua_get([[vim.fn.maparg('<C-LeftMouse>', 't', false, true).buffer]]), 1)
  eq(child.lua_get([[vim.fn.maparg('gf', 'n', false, true).buffer]]), 1)
end

return T
