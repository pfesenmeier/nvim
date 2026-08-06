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

return T
