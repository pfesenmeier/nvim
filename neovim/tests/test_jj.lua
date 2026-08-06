local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Pure helpers are exercised in this process: they touch no state, so paying for
-- a child restart (and RPC serialization) would buy nothing.
local H = require('huey.jj').H

local test_dir = 'tests/dir-jj'

-- Temp jj repos are torn down after each case that made one
local temp_roots = {}
local new_jj_repo = function(files)
  local root = helpers.new_jj_repo(files)
  table.insert(temp_roots, root)
  return root
end
local new_plain_dir = function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  table.insert(temp_roots, dir)
  return dir
end
local cleanup_temp_roots = function()
  for _, root in ipairs(temp_roots) do
    vim.fn.delete(root, 'rf')
  end
  temp_roots = {}
end

local T = new_set({ hooks = { post_case = cleanup_temp_roots } })

-- Unit tests ================================================================

T['H.ensure_text_width()'] = new_set()

T['H.ensure_text_width()']['pads short text'] = function()
  eq(H.ensure_text_width('ab', 5), 'ab   ')
end

T['H.ensure_text_width()']['leaves exact-width text'] = function()
  eq(H.ensure_text_width('abcde', 5), 'abcde')
end

T['H.ensure_text_width()']['truncates from the left with an ellipsis'] = function()
  -- keeps the *tail*, which is the informative end of a path
  eq(H.ensure_text_width('abcdefgh', 5), '…efgh')
end

T['H.fileset()'] = new_set()

T['H.fileset()']['quotes a workspace-relative path'] = function()
  eq(H.fileset('a/b c.lua'), 'root-file:"a/b c.lua"')
end

T['H.difflines_to_hunkitems()'] = new_set()

local fixture_items = function()
  local lines = vim.fn.readfile(test_dir .. '/diff-multi-file.txt')
  return H.difflines_to_hunkitems(lines)
end

T['H.difflines_to_hunkitems()']['splits every hunk into an item'] = function()
  eq(#fixture_items(), 4)
end

T['H.difflines_to_hunkitems()']['assigns each hunk its file'] = function()
  local paths = vim.tbl_map(function(x) return x.path end, fixture_items())
  eq(paths, { 'added.txt', 'main.txt', 'main.txt', 'other.txt' })
end

T['H.difflines_to_hunkitems()']['does not read a path from `/dev/null`'] = function()
  -- new-file hunks emit `--- /dev/null` before `+++ b/added.txt`
  eq(fixture_items()[1].path, 'added.txt')
end

T['H.difflines_to_hunkitems()']['points lnum at the first changed line'] = function()
  -- not the first *context* line: the second main.txt hunk starts at buffer line
  -- 7 but its first `-` is 3 context lines in
  local lnums = vim.tbl_map(function(x) return x.lnum end, fixture_items())
  eq(lnums, { 1, 1, 10, 2 })
end

T['H.difflines_to_hunkitems()']['keeps file header separate from hunk'] = function()
  local item = fixture_items()[2]
  eq(item.header[1], 'diff --git a/main.txt b/main.txt')
  eq(item.hunk[1], '@@ -1,4 +1,4 @@')
  eq(item.hunk[2], '-alpha')
end

T['H.difflines_to_hunkitems()']['aligns text columns across items'] = function()
  local texts = vim.tbl_map(function(x) return x.text end, fixture_items())
  local widths = vim.tbl_map(function(x) return vim.fn.strchars(x) end, texts)
  eq(widths, { widths[1], widths[1], widths[1], widths[1] })
  expect.match(texts[2], '^main%.txt%s+│ %-1,4 %+1,4%s+│')
end

T['H.difflines_to_hunkitems()']['handles empty input'] = function()
  eq(H.difflines_to_hunkitems({}), {})
end

T['H.hunks_applied_to_ref()'] = new_set()

local ref = { 'a', 'b', 'c', 'd', 'e' }

T['H.hunks_applied_to_ref()']['applies selected hunks'] = new_set({
  parametrize = {
    {
      'change one line',
      { 'a', 'B', 'c', 'd', 'e' },
      { { buf_start = 2, buf_count = 1, ref_start = 2, ref_count = 1 } },
      { 'a', 'B', 'c', 'd', 'e' },
    },
    {
      'add after a line',
      { 'a', 'b', 'X', 'c', 'd', 'e' },
      { { buf_start = 3, buf_count = 1, ref_start = 2, ref_count = 0 } },
      { 'a', 'b', 'X', 'c', 'd', 'e' },
    },
    {
      'add at start of file',
      { 'X', 'a', 'b', 'c', 'd', 'e' },
      { { buf_start = 1, buf_count = 1, ref_start = 0, ref_count = 0 } },
      { 'X', 'a', 'b', 'c', 'd', 'e' },
    },
    {
      'delete lines',
      { 'a', 'd', 'e' },
      { { buf_start = 1, buf_count = 0, ref_start = 2, ref_count = 2 } },
      { 'a', 'd', 'e' },
    },
    {
      'only the second of two hunks',
      { 'A', 'b', 'c', 'D', 'e' },
      { { buf_start = 4, buf_count = 1, ref_start = 4, ref_count = 1 } },
      { 'a', 'b', 'c', 'D', 'e' },
    },
    {
      'both of two hunks',
      { 'A', 'b', 'c', 'D', 'e' },
      {
        { buf_start = 1, buf_count = 1, ref_start = 1, ref_count = 1 },
        { buf_start = 4, buf_count = 1, ref_start = 4, ref_count = 1 },
      },
      { 'A', 'b', 'c', 'D', 'e' },
    },
    {
      'hunks supplied out of order',
      { 'A', 'b', 'c', 'D', 'e' },
      {
        { buf_start = 4, buf_count = 1, ref_start = 4, ref_count = 1 },
        { buf_start = 1, buf_count = 1, ref_start = 1, ref_count = 1 },
      },
      { 'A', 'b', 'c', 'D', 'e' },
    },
  },
}, {
  test = function(_, buf_lines, hunks, want)
    eq(H.hunks_applied_to_ref(ref, buf_lines, hunks), want)
  end,
})

T['H.hunks_applied_to_ref()']['does not mutate its hunks argument'] = function()
  local hunks = {
    { buf_start = 4, buf_count = 1, ref_start = 4, ref_count = 1 },
    { buf_start = 1, buf_count = 1, ref_start = 1, ref_count = 1 },
  }
  H.hunks_applied_to_ref(ref, { 'A', 'b', 'c', 'D', 'e' }, hunks)
  eq(hunks[1].ref_start, 4)
end

T['H.op_heads_dir()'] = new_set()

T['H.op_heads_dir()']['finds the op log head of a workspace'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = { 'x' } })
  eq(H.op_heads_dir(root), root .. '/.jj/repo/op_heads/heads')
end

T['H.op_heads_dir()']['follows `.jj/repo` when it is a file'] = function()
  -- secondary `jj workspace` checkouts store the repo path there instead
  local dir = new_plain_dir()
  vim.fn.mkdir(dir .. '/.jj', 'p')
  vim.fn.writefile({ '/somewhere/repo' }, dir .. '/.jj/repo')
  eq(H.op_heads_dir(dir), '/somewhere/repo/op_heads/heads')
end

T['H.op_heads_dir()']['returns nil without `.jj`'] = function()
  eq(H.op_heads_dir(new_plain_dir()), nil)
end

T['H.parse_subcommand()'] = new_set()

T['H.parse_subcommand()']['finds a bare subcommand'] = function()
  eq(H.parse_subcommand({ 'status' }), 'status')
end

T['H.parse_subcommand()']['skips boolean global flags'] = function()
  eq(H.parse_subcommand({ '--quiet', '--ignore-working-copy', 'log' }), 'log')
end

T['H.parse_subcommand()']['skips a global flag with a separate value'] = function()
  eq(H.parse_subcommand({ '-R', '/tmp/x', 'log' }), 'log')
end

T['H.parse_subcommand()']['skips a global flag with an inline value'] = function()
  eq(H.parse_subcommand({ '--color=never', 'log' }), 'log')
end

T['H.parse_subcommand()']['resolves jj default aliases'] = new_set({
  parametrize = {
    { 'b', 'bookmark' },
    { 'ci', 'commit' },
    { 'desc', 'describe' },
    { 'op', 'operation' },
    { 'st', 'status' },
  },
}, {
  test = function(alias, want) eq(H.parse_subcommand({ alias }), want) end,
})

T['H.parse_subcommand()']['joins a container with its second word'] = function()
  eq(H.parse_subcommand({ 'op', 'log' }), 'operation log')
  eq(H.parse_subcommand({ 'file', 'show', 'f.txt' }), 'file show')
end

T['H.parse_subcommand()']['leaves a container alone before a flag'] = function()
  eq(H.parse_subcommand({ 'op', '--help' }), 'operation')
end

T['H.parse_subcommand()']['returns nil without a subcommand'] = new_set({
  parametrize = { { { '--help' } }, { { '--', 'f.txt' } }, { {} } },
}, {
  test = function(args) eq(H.parse_subcommand(args), nil) end,
})

T['H.global_prefix()'] = new_set()

T['H.global_prefix()']['injects both flags by default'] = function()
  eq(H.global_prefix({ 'log' }), { '--no-pager', '--color=never' })
end

-- jj rejects a repeated `--color`/`--no-pager` outright, so a duplicate here
-- would make the whole command fail
T['H.global_prefix()']['omits a flag the user supplied'] = new_set({
  parametrize = {
    { { '--no-pager', 'log' }, { '--color=never' } },
    { { '--color=always', 'log' }, { '--no-pager' } },
    { { '--color', 'always', 'log' }, { '--no-pager' } },
    { { '--no-pager', '--color=always', 'log' }, {} },
  },
}, {
  test = function(args, want) eq(H.global_prefix(args), want) end,
})

T['H.complete_words()'] = new_set()

T['H.complete_words()']['splits the arguments'] = function()
  eq(H.complete_words('Jj log -r @', 11), { 'log', '-r', '@' })
end

-- jj's completion engine needs the word being completed as its own argument
T['H.complete_words()']['appends an empty word after a trailing space'] = function()
  eq(H.complete_words('Jj log ', 7), { 'log', '' })
end

T['H.complete_words()']['unescapes backslashed spaces'] = function()
  eq(H.complete_words([[Jj file show a\ b]], 18), { 'file', 'show', 'a b' })
end

T['H.complete_words()']['stops at the cursor'] = function()
  eq(H.complete_words('Jj log -r @', 6), { 'log' })
end

T['H.complete_words()']['ignores the bang and command modifiers'] = function()
  eq(H.complete_words('Jj! new', 7), { 'new' })
  eq(H.complete_words('vertical Jj log', 15), { 'log' })
end

T['H.split_filetype()'] = new_set()

--- The `file show` branch reads the buffer name, so give it a real buffer.
local split_filetype = function(name, lines, subcommand)
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf_id, name)
  local res = H.split_filetype(buf_id, lines, subcommand)
  vim.api.nvim_buf_delete(buf_id, { force = true })
  return res
end

T['H.split_filetype()']['detects a git-format diff from content'] = function()
  -- `jj diff` only emits this with `--git`; its default is color-words
  local lines = { 'diff --git a/f.txt b/f.txt' }
  eq(split_filetype('jj://1/jj diff --git', lines, 'diff'), 'diff')
end

T['H.split_filetype()']['detects file content from the buffer name'] = function()
  eq(split_filetype('jj://1/jj file show a.lua', { 'return 1' }, 'file show'), 'lua')
end

T['H.split_filetype()']['leaves log output unset'] = function()
  local lines = { '@  qrxzytsk you@example.com', '│  base' }
  eq(split_filetype('jj://1/jj log', lines, 'log'), nil)
end

-- Integration tests =========================================================

local child_set = function()
  return new_set({ hooks = { pre_case = child.setup, post_once = child.stop } })
end

T['pick_hunks()'] = child_set()

local mock_pick = function()
  child.lua([[
    require('mini.pick').setup()
    _G.captured = nil
    MiniPick.builtin.cli = function(cli_opts, opts) _G.captured = { cli = cli_opts, opts = opts } end

    _G.git_call = nil
    package.loaded['mini.extra'] = {
      pickers = { git_hunks = function(lo, o) _G.git_call = { local_opts = lo, opts = o } end },
    }

    _G.notified = {}
    vim.notify = function(msg, level) table.insert(_G.notified, { msg = msg, level = level }) end

    _G.pick_hunks = function(local_opts) require('huey.jj').pick_hunks(local_opts) end
  ]])
end

T['pick_hunks()']['builds the diff command for `@`'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = { 'x' } })
  mock_pick()
  child.fn.chdir(root)
  child.lua('_G.pick_hunks({})')

  eq(child.lua_get('_G.captured.cli.command'), {
    'jj',
    '--no-pager',
    '--color=never',
    'diff',
    '--git',
    '--context=3',
    '-r',
    '@',
  })
  eq(child.lua_get('_G.captured.opts.source.cwd'), root)
  eq(child.lua_get('_G.captured.opts.source.name'), 'jj hunks (@, all)')
end

T['pick_hunks()']['builds the diff command for `@-`'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = { 'x' } })
  mock_pick()
  child.fn.chdir(root)
  child.lua('_G.pick_hunks({ revset = "@-" })')

  expect.contains(child.lua_get('_G.captured.cli.command'), '@-')
  eq(child.lua_get('_G.captured.opts.source.name'), 'jj hunks (@-, all)')
end

T['pick_hunks()']['snapshots the working copy'] = function()
  -- the opposite of the diff source: `-r @` must reflect on-disk edits
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = { 'x' } })
  mock_pick()
  child.fn.chdir(root)
  child.lua('_G.pick_hunks({})')

  local command = child.lua_get('_G.captured.cli.command')
  eq(vim.tbl_contains(command, '--ignore-working-copy'), false)
end

T['pick_hunks()']['scopes to a path with a fileset'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['sub/f.txt'] = { 'x' } })
  mock_pick()
  child.fn.chdir(root)
  child.lua('_G.pick_hunks({ path = ... })', { root .. '/sub/f.txt' })

  local command = child.lua_get('_G.captured.cli.command')
  eq({ command[#command - 1], command[#command] }, { '--', 'root-file:"sub/f.txt"' })
  eq(child.lua_get('_G.captured.opts.source.name'), 'jj hunks (@, for path)')
end

T['pick_hunks()']['accepts a cwd-relative path'] = function()
  -- `:Pick jj_hunks path="%"` expands to a cwd-relative path, not an absolute one
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['sub/f.txt'] = { 'x' } })
  mock_pick()
  child.fn.chdir(root)
  child.lua('_G.pick_hunks({ path = "sub/f.txt" })')

  local command = child.lua_get('_G.captured.cli.command')
  eq(command[#command], 'root-file:"sub/f.txt"')
end

T['pick_hunks()']['falls back to git hunks'] = new_set({
  parametrize = { { '@', 'unstaged' }, { '@-', 'staged' } },
}, {
  test = function(revset, scope)
    local dir = new_plain_dir()
    mock_pick()
    child.fn.chdir(dir)
    child.lua('_G.pick_hunks({ revset = ... })', { revset })

    eq(child.lua_get('_G.git_call.local_opts.scope'), scope)
    eq(child.lua_get('_G.captured'), vim.NIL)
  end,
})

T['pick_hunks()']['notifies for a revset with no git analogue'] = function()
  local dir = new_plain_dir()
  mock_pick()
  child.fn.chdir(dir)
  child.lua('_G.pick_hunks({ revset = "@--" })')

  eq(child.lua_get('_G.git_call'), vim.NIL)
  eq(#child.lua_get('_G.notified'), 1)
  expect.match(child.lua_get('_G.notified[1].msg'), 'no git scope for @%-%-')
  eq(child.lua_get('_G.notified[1].level'), child.lua_get('vim.log.levels.WARN'))
end

T['gen_diff_source()'] = child_set()

local base_lines = { 'one', 'two', 'three', 'four', 'five', 'six', 'seven' }
local edited_lines = { 'ONE', 'two', 'three', 'four', 'five', 'SIX', 'seven' }

--- Sets up mini.diff with the jj source and opens `<root>/f.txt`.
local setup_diff = function(root)
  child.lua([[
    _G.jj_spawns = 0
    local system_orig = vim.system
    vim.system = function(cmd, opts, cb)
      if vim.tbl_contains(cmd, 'show') then
        _G.jj_spawns = _G.jj_spawns + 1
        _G.last_show = cmd
      end
      return system_orig(cmd, opts, cb)
    end

    local diff = require('mini.diff')
    diff.setup({ source = { require('huey.jj').gen_diff_source(), diff.gen_source.git() } })
  ]])
  child.cmd('edit ' .. root .. '/f.txt')
  return child.api.nvim_get_current_buf()
end

local ref_arrived = 'type((MiniDiff.get_buf_data(0) or {}).ref_text) == "string"'
-- fully parenthesized: these get concatenated with `== n`, and `or` binds looser
-- than `==`, so an unparenthesized fallback would make every wait pass instantly
local n_hunks = '#((MiniDiff.get_buf_data(0) or { hunks = {} }).hunks)'

T['gen_diff_source()']['uses file content at `@-` as reference'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = base_lines })
  vim.fn.writefile(edited_lines, root .. '/f.txt')

  setup_diff(root)
  eq(child.wait_for(ref_arrived), true)
  local want_ref = table.concat(base_lines, '\n') .. '\n'
  eq(child.lua_get('MiniDiff.get_buf_data(0).ref_text'), want_ref)
  eq(child.wait_for(n_hunks .. ' == 2'), true)
end

T['gen_diff_source()']['reads without snapshotting'] = function()
  -- otherwise the read records an operation, which trips the op-head watcher
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = base_lines })
  setup_diff(root)
  eq(child.wait_for(ref_arrived), true)

  expect.contains(child.lua_get('_G.last_show'), '--ignore-working-copy')
end

T['gen_diff_source()']['watcher does not re-trigger itself'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = base_lines })
  setup_diff(root)
  eq(child.wait_for(ref_arrived), true)

  local before = child.lua_get('_G.jj_spawns')
  vim.uv.sleep(helpers.get_time_const(1000))
  child.poke_eventloop()
  eq(child.lua_get('_G.jj_spawns'), before)
end

T['gen_diff_source()']['shows no hunks for a file absent at `@-`'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = base_lines })
  vim.fn.writefile({ 'brand new' }, root .. '/new.txt')

  setup_diff(root)
  eq(child.wait_for(ref_arrived), true)

  local before = child.lua_get('_G.jj_spawns')
  child.cmd('edit ' .. root .. '/new.txt')
  -- wait for the read to actually come back, else the assertion is vacuous
  eq(child.wait_for('_G.jj_spawns > ' .. before), true)
  child.poke_eventloop()

  eq(child.lua_get(n_hunks), 0)
  eq(child.lua_get('(MiniDiff.get_buf_data(0) or {}).ref_text'), vim.NIL)
end

T['gen_diff_source()']['falls through to the git source'] = function()
  local dir = new_plain_dir()
  vim.system({ 'git', 'init', '-q' }, { cwd = dir }):wait()
  vim.fn.writefile({ 'hello' }, dir .. '/f.txt')
  vim.system({ 'git', 'add', 'f.txt' }, { cwd = dir }):wait()

  setup_diff(dir)
  eq(child.wait_for(ref_arrived), true)
  eq(child.lua_get('MiniDiff.get_buf_data(0).config.source[1].name'), 'jj')
  -- source 1 is jj, but its `attach` returned false so git supplied the text
  eq(child.lua_get('MiniDiff.get_buf_data(0).ref_text'), 'hello\n')
end

T['gen_diff_source()']['apply_hunks squashes into `@-`'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = base_lines })
  vim.fn.writefile(edited_lines, root .. '/f.txt')
  local at_before = helpers.change_id(root, '@')

  setup_diff(root)
  eq(child.wait_for(n_hunks .. ' == 2'), true)

  -- apply only the first hunk
  child.lua('MiniDiff.do_hunks(0, "apply", { line_start = 1, line_end = 1 })')

  local show = function(revset)
    return helpers.jj(root, 'file', 'show', '-r', revset, 'f.txt')
  end

  local at_minus = vim.split(show('@-'), '\n')
  eq(at_minus[1], 'ONE')
  eq(at_minus[6], 'six')
  eq(vim.fn.readfile(root .. '/f.txt'), edited_lines)
  eq(helpers.change_id(root, '@'), at_before)
  eq(child.get_lines(), edited_lines)

  local at_content = vim.split(show('@'), '\n')
  eq({ at_content[1], at_content[6] }, { 'ONE', 'SIX' })

  eq(child.wait_for(n_hunks .. ' == 1'), true)
end

T['gen_diff_source()']['apply_hunks leaves an unsaved buffer alone'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = base_lines })

  setup_diff(root)
  eq(child.wait_for(ref_arrived), true)
  child.set_lines({ 'ONE' }, 0, 1)
  eq(child.wait_for(n_hunks .. ' == 1'), true)
  eq(child.bo.modified, true)

  child.lua('MiniDiff.do_hunks(0, "apply", { line_start = 1, line_end = 1 })')

  local at_minus = helpers.jj(root, 'file', 'show', '-r', '@-', 'f.txt')
  eq(vim.trim(at_minus):sub(1, 3), 'ONE')
  -- disk keeps the last *saved* content, matching `git apply --cached`
  eq(vim.fn.readfile(root .. '/f.txt'), base_lines)
  eq(child.bo.modified, true)
  eq(child.get_lines()[1], 'ONE')
end

T[':Jj'] = child_set()

--- Stubs the async `vim.system` path. `:wait()` calls -- `jj root` and the
--- completion engine -- fall through to the real thing.
local mock_jj = function()
  child.lua([[
    _G.spawns, _G.notified, _G.stub = {}, {}, {}
    local system_orig = vim.system
    vim.system = function(cmd, opts, cb)
      if cb == nil then return system_orig(cmd, opts) end
      table.insert(_G.spawns, { cmd = cmd, opts = opts })
      if _G.stub.hang then return { kill = function() end } end
      local out = vim.tbl_extend('force', { code = 0, stdout = '', stderr = '' }, _G.stub)
      vim.schedule(function() cb(out) end)
      return { kill = function() end }
    end
    vim.notify = function(msg, level) table.insert(_G.notified, { msg = msg, level = level }) end
    require('huey.jj').setup()
  ]])
end

--- @param stub table? fields of the faked `vim.system` result
local set_stub = function(stub) child.lua('_G.stub = ...', { stub or {} }) end

--- Number of spawned arguments matching `pattern`.
local n_matching = function(pattern)
  local cmd = child.lua_get('_G.spawns[1].cmd')
  return #vim.tbl_filter(function(x) return x:find(pattern) ~= nil end, cmd)
end

--- One field of the `:Jj` definition; the whole entry holds the Lua `complete`
--- callback, which does not survive the RPC round trip.
local command_field = function(name)
  return child.lua_get('vim.api.nvim_get_commands({}).Jj.' .. name)
end

T[':Jj']['is registered by setup()'] = function()
  mock_jj()
  eq(command_field('bang'), true)
  eq(command_field('nargs'), '+')
  expect.match(command_field('definition'), 'jj command')
end

T[':Jj']['prepends jj global flags'] = function()
  mock_jj()
  child.cmd('Jj status')
  local cmd = child.lua_get('_G.spawns[1].cmd')
  eq(cmd[1], 'jj')
  expect.contains(cmd, '--no-pager')
  expect.contains(cmd, '--color=never')
  expect.contains(cmd, 'status')
end

-- jj errors out on a repeated `--color`, so the injection has to stand down
T[':Jj']['does not duplicate a user-supplied global flag'] = function()
  mock_jj()
  child.cmd('Jj --color=always status')
  eq(n_matching('^%-%-color'), 1)
  eq(n_matching('^%-%-no%-pager'), 1)
end

T[':Jj']['runs in the workspace root'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['sub/f.txt'] = { 'x' } })
  mock_jj()
  child.fn.chdir(root .. '/sub')
  child.cmd('Jj status')

  eq(child.lua_get('_G.spawns[1].opts.cwd'), root)
end

T[':Jj']['falls back to cwd outside a workspace'] = function()
  local dir = new_plain_dir()
  mock_jj()
  child.fn.chdir(dir)
  child.cmd('Jj status')

  eq(child.lua_get('_G.spawns[1].opts.cwd'), dir)
end

-- jj reports the new working copy on stderr after every mutation, so unlike
-- 'mini.git' a non-empty stderr with exit 0 is informational, not a warning
T[':Jj']['notifies stderr at INFO on success'] = function()
  mock_jj()
  set_stub({ stderr = 'Working copy  (@) now at: abc\n' })
  child.cmd('Jj new')

  eq(#child.lua_get('_G.notified'), 1)
  eq(child.lua_get('_G.notified[1].msg'), 'Working copy  (@) now at: abc')
  eq(child.lua_get('_G.notified[1].level'), child.lua_get('vim.log.levels.INFO'))
end

T[':Jj']['notifies at ERROR on failure'] = function()
  mock_jj()
  set_stub({ code = 1, stderr = "Error: Revision `nope` doesn't exist" })
  child.cmd('Jj log -r nope')

  eq(child.lua_get('_G.notified[1].level'), child.lua_get('vim.log.levels.ERROR'))
  expect.match(child.lua_get('_G.notified[1].msg'), 'Revision `nope`')
end

T[':Jj']['appends stdout to an error notification'] = function()
  mock_jj()
  set_stub({ code = 1, stderr = 'boom', stdout = 'partial' })
  child.cmd('Jj status')

  eq(child.lua_get('_G.notified[1].msg'), 'boom\npartial')
end

T[':Jj']['notifies stdout for a non-info subcommand'] = function()
  mock_jj()
  set_stub({ stdout = '/tmp/repo' })
  child.cmd('Jj root')

  eq(child.lua_get('_G.notified[1].msg'), '/tmp/repo')
  eq(#child.lua_get('vim.api.nvim_list_wins()'), 1)
end

T[':Jj']['shows stdout in a split'] = new_set({
  parametrize = {
    { 'Jj status', 'jj status' },
    -- two-word subcommand: `operation log` has to resolve through the alias
    { 'Jj op log', 'jj op log' },
    -- forced by a modifier despite `new` not being an info subcommand
    { 'vertical Jj new', 'jj new' },
  },
}, {
  test = function(cmd, want_name)
    mock_jj()
    set_stub({ stdout = 'line one\nline two' })
    child.cmd(cmd)

    eq(#child.lua_get('vim.api.nvim_list_wins()'), 2)
    local pattern = '^jj://%d+/' .. vim.pesc(want_name) .. '$'
    expect.match(child.api.nvim_buf_get_name(0), pattern)
    eq(child.get_lines(), { 'line one', 'line two' })
    eq(#child.lua_get('_G.notified'), 0)
  end,
})

T[':Jj']['honors `:silent`'] = function()
  mock_jj()
  set_stub({ stdout = 'out', stderr = 'err' })
  child.cmd('silent Jj status')

  eq(#child.lua_get('vim.api.nvim_list_wins()'), 1)
  eq(#child.lua_get('_G.notified'), 0)
end

T[':Jj']['types git-format output as a diff'] = function()
  mock_jj()
  set_stub({ stdout = 'diff --git a/f b/f\n@@ -1 +1 @@' })
  child.cmd('Jj diff --git')

  eq(child.bo.filetype, 'diff')
end

T[':Jj']['leaves untyped output unfolded'] = function()
  mock_jj()
  set_stub({ stdout = '@  qrxzytsk\n│  base' })
  child.cmd('Jj log')

  eq(child.bo.filetype, '')
  eq(child.wo.foldlevel, 999)
end

T[':Jj']['closing the split wipes its buffer'] = function()
  mock_jj()
  set_stub({ stdout = 'out' })
  child.cmd('Jj status')
  local buf_id = child.api.nvim_get_current_buf()

  child.cmd('close')
  eq(child.wait_for('not vim.api.nvim_buf_is_valid(' .. buf_id .. ')'), true)
end

-- jj's diff editor is a directory-pair TUI; `vim.system` gives it no pty
T[':Jj']['runs diff-editor subcommands in a terminal'] = new_set({
  parametrize = { { 'split' }, { 'diffedit' }, { 'resolve' }, { 'squash -i' } },
}, {
  test = function(args)
    mock_jj()
    child.cmd('Jj ' .. args)

    eq(#child.lua_get('_G.spawns'), 0)
    eq(child.bo.buftype, 'terminal')
    -- arguments reach the shell quoted, so match loosely
    local pattern = 'jj .*' .. vim.pesc(args:match('^%S+'))
    expect.match(child.api.nvim_buf_get_name(0), pattern)
  end,
})

T[':Jj']['waits for the job unless banged'] = new_set({
  parametrize = { { 'Jj status', true }, { 'Jj! status', false } },
}, {
  test = function(cmd, should_wait)
    mock_jj()
    child.lua('require("huey.jj").H.timeout = ...', { helpers.get_time_const(400) })
    child.lua('_G.stub = { hang = true }')

    local start = vim.uv.hrtime()
    child.cmd(cmd)
    local elapsed_ms = (vim.uv.hrtime() - start) / 1e6
    eq(elapsed_ms > helpers.get_time_const(200), should_wait)
  end,
})

T[':Jj']['reloads changed buffers afterwards'] = function()
  local dir = new_plain_dir()
  vim.fn.writefile({ 'before' }, dir .. '/f.txt')
  mock_jj()
  child.o.autoread = true
  child.cmd('edit ' .. dir .. '/f.txt')
  eq(child.get_lines(), { 'before' })

  vim.fn.writefile({ 'after' }, dir .. '/f.txt')
  child.cmd('Jj new')

  eq(child.get_lines(), { 'after' })
end

T[':Jj completion'] = child_set()

local complete = function(cmdline) return child.fn.getcompletion(cmdline, 'cmdline') end

local setup_completion = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = { 'x' } })
  child.lua('require("huey.jj").setup()')
  child.fn.chdir(root)
  return root
end

T[':Jj completion']['completes subcommands'] = function()
  setup_completion()
  expect.contains(complete('Jj '), 'status')
  expect.contains(complete('Jj de'), 'describe')
end

T[':Jj completion']['completes a two-word subcommand'] = function()
  setup_completion()
  expect.contains(complete('Jj op '), 'log')
end

T[':Jj completion']['completes revsets'] = function()
  local root = setup_completion()
  helpers.jj(root, 'bookmark', 'create', 'feature', '-r', '@-')
  expect.contains(complete('Jj log -r '), 'feature')
end

T[':Jj completion']['completes paths'] = function()
  setup_completion()
  expect.contains(complete('Jj file show '), 'f.txt')
end

T[':Jj completion']['falls back to a static list'] = function()
  setup_completion()
  child.lua([[
    local failed = { wait = function() return { code = 1 } end }
    vim.system = function() return failed end
  ]])
  expect.contains(complete('Jj st'), 'status')
end

-- holding <Tab> must not churn `gen_diff_source()`'s reference text
T[':Jj completion']['does not snapshot the working copy'] = function()
  local root = setup_completion()
  local op_head = function()
    return helpers.jj(root, 'op', 'log', '--no-graph', '-n', '1', '-T', 'id.short()')
  end
  local before = op_head()

  complete('Jj ')
  complete('Jj log -r ')
  complete('Jj file show ')

  eq(op_head(), before)
end

T[':Jj describe'] = child_set()

T[':Jj describe']['passes `ui.editor` as a TOML array'] = function()
  mock_jj()
  child.cmd('Jj describe')

  local cmd = child.lua_get('_G.spawns[1].cmd')
  local i = vim.fn.index(cmd, '--config') + 1
  expect.match(cmd[i + 1], '^ui%.editor=%[')
end

-- the full bridge: jj spawns a headless Nvim, which RPCs back here to open the
-- description; closing the split is what lets jj finish
T[':Jj describe']['edits the description in a split'] = function()
  helpers.skip_if_no_jj()
  local root = new_jj_repo({ ['f.txt'] = { 'x' } })
  child.lua([[
    _G.notified = {}
    vim.notify = function(msg) table.insert(_G.notified, msg) end
    require('huey.jj').setup()
  ]])
  child.fn.chdir(root)

  -- generous: this spawns a whole second Nvim, which then RPCs back
  local timeout = helpers.get_time_const(15000)

  child.cmd('Jj! describe')
  eq(child.wait_for('#vim.api.nvim_list_wins() == 2', timeout), true)
  expect.match(child.api.nvim_buf_get_name(0), '%.jjdescription$')

  child.set_lines({ 'from the split' }, 0, 1)
  child.cmd('write')
  child.cmd('close')

  eq(child.wait_for('#_G.notified > 0', timeout), true)
  local desc = helpers.jj(root, 'log', '--no-graph', '-r', '@', '-T', 'description')
  eq(desc, 'from the split\n')
  expect.match(child.lua_get('_G.notified[1]'), 'Working copy')
end

return T
