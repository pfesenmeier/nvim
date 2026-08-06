-- module for working with jj diff hunks: a 'mini.pick' picker and a 'mini.diff'
-- source
--
-- jj has no index, so the git staged/unstaged split maps onto revisions instead:
-- `@` (working copy commit) stands in for unstaged, `@-` for staged. Both entry
-- points fall back to their git equivalent when there is no jj workspace.
local HueyJj = {}
local H = {}

--- @class JjHunksOpts
--- @field revset? string    revision to diff against its parent, default '@'
--- @field path? string      absolute path to restrict the diff to
--- @field n_context? number lines of context per hunk, default 3

--- `@`/`@-` have direct git analogues; anything else is jj-only.
local git_scopes = { ['@'] = 'unstaged', ['@-'] = 'staged' }

--- jj's global flags, which may precede the subcommand. `true` marks one that
--- takes a separate value argument.
--stylua: ignore
local global_flags = {
  ['-R'] = true, ['--repository'] = true, ['--at-op'] = true,
  ['--at-operation'] = true, ['--color'] = true, ['--config'] = true,
  ['--config-file'] = true,

  ['--debug'] = false, ['--help'] = false, ['--ignore-immutable'] = false,
  ['--ignore-working-copy'] = false, ['--no-integrate-operation'] = false,
  ['--no-pager'] = false, ['--quiet'] = false, ['--version'] = false,
}

--- jj's built-in subcommand aliases.
--stylua: ignore
local aliases = {
  b = 'bookmark', ci = 'commit', desc = 'describe', op = 'operation',
  st = 'status', ['evolution-log'] = 'evolog',
}

--- Subcommands whose real name is two words. Kept as a set rather than
--- enumerating every valid suffix, so new jj subcommands work unchanged.
--stylua: ignore
local containers = {
  bisect = true, bookmark = true, config = true, file = true, gerrit = true,
  git = true, operation = true, sparse = true, tag = true, util = true,
  workspace = true,
}

--- Subcommands whose stdout goes to a split rather than a notification. Names
--- are post-alias-resolution. jj has no `git --list-cmds`, so this is static.
--- Single-line reporters (`root`, `version`, `config get`) read better as a
--- notification and are deliberately absent.
--stylua: ignore
local info_subcommands = {
  ['diff'] = true, ['evolog'] = true, ['help'] = true, ['interdiff'] = true,
  ['log'] = true, ['show'] = true, ['status'] = true,

  ['bookmark list'] = true, ['config list'] = true, ['file annotate'] = true,
  ['file list'] = true, ['file show'] = true, ['operation diff'] = true,
  ['operation log'] = true, ['operation show'] = true, ['sparse list'] = true,
  ['tag list'] = true, ['workspace list'] = true,
}

--- Subcommands driving jj's *diff* editor, a directory-pair TUI that needs a
--- real pty. Run in `:terminal` instead of `vim.system`.
local diff_editor_subcommands = { diffedit = true, resolve = true, split = true }

--- Completion fallback for when jj's own engine is unavailable.
--stylua: ignore
local subcommands = {
  'abandon', 'absorb', 'arrange', 'bisect', 'bookmark', 'commit', 'config',
  'describe', 'diff', 'diffedit', 'duplicate', 'edit', 'evolog', 'file', 'fix',
  'gerrit', 'git', 'help', 'interdiff', 'log', 'metaedit', 'new', 'next',
  'operation', 'parallelize', 'prev', 'rebase', 'redo', 'resolve', 'restore',
  'revert', 'root', 'run', 'show', 'sign', 'simplify-parents', 'sparse',
  'split', 'squash', 'status', 'tag', 'undo', 'unsign', 'util', 'version',
  'workspace',
}

--- Locates the jj workspace containing `dir`.
--- @param dir string
--- @return string?
H.workspace_root = function(dir)
  local out = vim.system({ 'jj', 'root' }, { cwd = dir, text = true }):wait()
  if out.code ~= 0 then return nil end
  return vim.trim(out.stdout)
end

--- Workspace-relative path as a jj fileset. See `jj help -k filesets`.
--- @param relpath string
--- @return string
H.fileset = function(relpath) return ('root-file:"%s"'):format(relpath) end

--- @param text string
--- @param width number
--- @return string
H.ensure_text_width = function(text, width)
  local text_width = vim.fn.strchars(text)
  if text_width <= width then return text .. string.rep(' ', width - text_width) end
  return '…' .. vim.fn.strcharpart(text, text_width - width + 1, width - 1)
end

--- Splits a git-format unified diff into one picker item per hunk.
--- Ported from the private `H.git_difflines_to_hunkitems` in 'mini.extra'; `jj diff
--- --git` always emits 'a/'/'b/', so the mnemonic-prefix handling is dropped.
--- @param lines string[]
--- @return table[]
H.difflines_to_hunkitems = function(lines)
  local cur_header, cur_path, is_in_hunk = {}, nil, false
  local items = {}
  for _, l in ipairs(lines) do
    -- Separate path header and hunk for better granularity
    if l:find('^diff %-%-git') ~= nil then
      is_in_hunk = false
      cur_header = {}
    end

    local path_match = l:match('^%+%+%+ b/(.*)$') or l:match('^%-%-%- a/(.*)$')
    if path_match ~= nil and not is_in_hunk then cur_path = path_match end

    local hunk_start = l:match('^@@ %-%d+,?%d* %+(%d+),?%d* @@')
    if hunk_start ~= nil then
      is_in_hunk = true
      local item = { path = cur_path, lnum = tonumber(hunk_start), hunk = {} }
      item.header = vim.deepcopy(cur_header)
      table.insert(items, item)
    end

    if is_in_hunk then
      table.insert(items[#items].hunk, l)
    else
      table.insert(cur_header, l)
    end
  end

  -- Point line number at the first changed line instead of the first context line
  for _, item in ipairs(items) do
    for i = 2, #item.hunk do
      if item.hunk[i]:find('^[+-]') ~= nil then
        item.lnum = item.lnum + i - 2
        break
      end
    end
  end

  -- Construct aligned text from path and hunk header
  local text_parts, path_width, coords_width = {}, 0, 0
  for i, item in ipairs(items) do
    local coords, title = item.hunk[1]:match('@@ (.-) @@ ?(.*)$')
    coords, title = coords or '', title or ''
    text_parts[i] = { item.path, coords, title }
    path_width = math.max(path_width, vim.fn.strchars(item.path))
    coords_width = math.max(coords_width, vim.fn.strchars(coords))
  end

  for i, item in ipairs(items) do
    local parts = text_parts[i]
    local path = H.ensure_text_width(parts[1], path_width)
    local coords = H.ensure_text_width(parts[2], coords_width)
    item.text = string.format('%s │ %s │ %s', path, coords, parts[3])
  end

  return items
end

--- @param buf_id number
--- @param item table
H.preview = function(buf_id, item)
  local ts_opts = { error = false }
  local ok, parser = pcall(vim.treesitter.get_parser, buf_id, 'diff', ts_opts)
  local has_parser = ok and parser ~= nil
  if has_parser then has_parser = pcall(vim.treesitter.start, buf_id, 'diff') end
  if not has_parser then vim.bo[buf_id].syntax = 'diff' end

  local lines = vim.deepcopy(item.header)
  vim.list_extend(lines, item.hunk)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

--- Picks a hunk from `jj diff -r <revset>`.
--- @param local_opts JjHunksOpts?
--- @param opts table? forwarded to `MiniPick.start`
HueyJj.pick_hunks = function(local_opts, opts)
  local defaults = { revset = '@', n_context = 3 }
  local_opts = vim.tbl_deep_extend('force', defaults, local_opts or {})
  local revset, n_context = local_opts.revset, local_opts.n_context

  local path = local_opts.path
  if path ~= nil then path = vim.fn.fnamemodify(path, ':p') end
  local dir = path == nil and vim.fn.getcwd() or vim.fn.fnamemodify(path, ':h')

  local root = H.workspace_root(dir)
  if root == nil then
    local scope = git_scopes[revset]
    if scope == nil then
      local msg = ('No jj workspace at %s; no git scope for %s'):format(dir, revset)
      vim.notify(msg, vim.log.levels.WARN)
      return
    end
    local git_opts = { scope = scope, path = path }
    return require('mini.extra').pickers.git_hunks(git_opts, opts)
  end

  -- Snapshotting is intentional: it is what makes `-r @` reflect on-disk edits
  local command = {
    'jj',
    '--no-pager',
    '--color=never',
    'diff',
    '--git',
    '--context=' .. n_context,
    '-r',
    revset,
  }
  if path ~= nil then
    local relpath = vim.fs.relpath(root, path)
    if relpath == nil then
      local msg = ('%s is outside jj workspace %s'):format(path, root)
      vim.notify(msg, vim.log.levels.WARN)
      return
    end
    vim.list_extend(command, { '--', H.fileset(relpath) })
  end

  local default_source = {
    name = ('jj hunks (%s, %s)'):format(revset, path == nil and 'all' or 'for path'),
    cwd = root,
    show = function(buf_id, items, query)
      return MiniPick.default_show(buf_id, items, query, { show_icons = true })
    end,
    preview = H.preview,
  }
  opts = vim.tbl_deep_extend('force', { source = default_source }, opts or {})

  local cli_opts = { command = command, postprocess = H.difflines_to_hunkitems }
  return MiniPick.builtin.cli(cli_opts, opts)
end

--- Directory holding the operation log head, which jj rewrites on every
--- operation. Watching it is the jj analogue of watching '.git/index'.
--- @param root string
--- @return string?
H.op_heads_dir = function(root)
  local repo = root .. '/.jj/repo'
  local stat = vim.uv.fs_stat(repo)
  if stat == nil then return nil end
  -- secondary workspaces store the repo path in '.jj/repo' instead of a directory
  if stat.type == 'file' then repo = vim.trim(vim.fn.readfile(repo)[1] or '') end
  if repo == '' then return nil end
  return repo .. '/op_heads/heads'
end

--- Reference text with only `hunks` applied, i.e. what the reference becomes
--- once those hunks are squashed into it.
--- @param ref_lines string[]
--- @param buf_lines string[]
--- @param hunks table[] per `:h MiniDiff-hunk-specification`
--- @return string[]
H.hunks_applied_to_ref = function(ref_lines, buf_lines, hunks)
  hunks = vim.deepcopy(hunks)
  table.sort(hunks, function(a, b) return a.ref_start < b.ref_start end)

  local res, ref_i = {}, 1
  for _, h in ipairs(hunks) do
    -- "add" hunks (`ref_count == 0`) sit *after* their reference line
    local copy_until = h.ref_start + (h.ref_count == 0 and 0 or -1)
    for i = ref_i, copy_until do
      table.insert(res, ref_lines[i])
    end
    for i = h.buf_start, h.buf_start + h.buf_count - 1 do
      table.insert(res, buf_lines[i])
    end
    ref_i = copy_until + h.ref_count + 1
  end
  for i = ref_i, #ref_lines do
    table.insert(res, ref_lines[i])
  end
  return res
end

--- Generates a 'mini.diff' source using file content at `revset` as reference,
--- so hunks are the changes made by the revision below it. Applying hunks
--- squashes them into `revset`.
--- @param revset string? default '@-'
--- @return table source per `:h MiniDiff-source-specification`
HueyJj.gen_diff_source = function(revset)
  revset = revset or '@-'
  local cache = {}

  local set_ref_text = vim.schedule_wrap(function(buf_id)
    local buf_cache = cache[buf_id]
    if buf_cache == nil or not vim.api.nvim_buf_is_valid(buf_id) then return end

    -- `--ignore-working-copy` keeps this read from recording an operation, which
    -- would trip the watcher below and loop forever
    local command = {
      'jj',
      '--ignore-working-copy',
      '--no-pager',
      '--color=never',
      'file',
      'show',
      '-r',
      revset,
      '--',
      H.fileset(buf_cache.rel_path),
    }
    local on_exit = vim.schedule_wrap(function(out)
      local valid = cache[buf_id] ~= nil and vim.api.nvim_buf_is_valid(buf_id)
      if not valid then return end
      -- absent at `revset` means a new file; unset so it shows no hunks at all,
      -- which is what the git source does for untracked files
      local text = out.code == 0 and out.stdout or {}
      pcall(MiniDiff.set_ref_text, buf_id, text)
    end)
    vim.system(command, { cwd = buf_cache.root, text = true }, on_exit)
  end)

  local watch = function(buf_id)
    local dir = H.op_heads_dir(cache[buf_id].root)
    if dir == nil then return end

    local fs_event, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
    cache[buf_id].fs_event, cache[buf_id].timer = fs_event, timer
    fs_event:start(dir, { recursive = false }, function()
      -- debounce: one jj operation can touch the directory several times
      timer:stop()
      timer:start(50, 0, function() set_ref_text(buf_id) end)
    end)
  end

  local attach = function(buf_id)
    if cache[buf_id] ~= nil then return false end

    -- resolve symlinks so the workspace is found from the file's real location
    local path = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(buf_id))
    if path == nil then return false end
    local root = H.workspace_root(vim.fs.dirname(path))
    if root == nil then return false end
    local rel_path = vim.fs.relpath(root, path)
    if rel_path == nil then return false end

    cache[buf_id] = { root = root, rel_path = rel_path }
    watch(buf_id)
    set_ref_text(buf_id)
  end

  local detach = function(buf_id)
    local buf_cache = cache[buf_id]
    cache[buf_id] = nil
    if buf_cache == nil then return end
    if buf_cache.timer ~= nil then buf_cache.timer:close() end
    if buf_cache.fs_event ~= nil then buf_cache.fs_event:close() end
  end

  local apply_hunks = function(buf_id, hunks)
    local buf_cache = cache[buf_id]
    local buf_data = MiniDiff.get_buf_data(buf_id)
    if buf_cache == nil or buf_data == nil then return end
    if buf_data.ref_text == nil then return end

    local ref_lines = vim.split(buf_data.ref_text, '\n')
    -- `ref_text` always ends in '\n', so drop the empty element it splits into
    if ref_lines[#ref_lines] == '' then table.remove(ref_lines) end
    local buf_lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    local new_lines = H.hunks_applied_to_ref(ref_lines, buf_lines, hunks)

    -- `jj squash` moves whole files, so the partially-applied content has to be
    -- on disk for the duration of the call and is restored right after
    local path = buf_cache.root .. '/' .. buf_cache.rel_path
    local on_disk = vim.fn.filereadable(path) == 1
    local disk_lines = on_disk and vim.fn.readfile(path, 'b') or nil
    vim.fn.writefile(new_lines, path)

    local command = {
      'jj',
      '--no-pager',
      '--color=never',
      'squash',
      -- keep `@` alive; jj otherwise abandons a source revision it empties
      '--keep-emptied',
      -- take the destination description rather than prompting to merge the two
      '--use-destination-message',
      '--into',
      revset,
      '--',
      H.fileset(buf_cache.rel_path),
    }
    local out = vim.system(command, { cwd = buf_cache.root, text = true }):wait()

    if disk_lines ~= nil then
      pcall(vim.fn.writefile, disk_lines, path, 'b')
    else
      pcall(vim.fn.delete, path)
    end
    vim.schedule(function() vim.cmd('silent! checktime ' .. buf_id) end)

    if out.code ~= 0 then vim.notify(vim.trim(out.stderr), vim.log.levels.ERROR) end
  end

  return { name = 'jj', attach = attach, detach = detach, apply_hunks = apply_hunks }
end

-- ':Jj' command ==============================================================
-- Modeled on 'mini.git's `:Git`: run jj asynchronously, show informational
-- stdout in a scratch split, and notify everything else. jj inverts git's
-- stream convention -- mutations exit 0 with empty stdout and report the new
-- working copy on stderr -- so exit-0 stderr is INFO here, not WARN.

H.timeout = 30000
H.complete_timeout = 500
--- Set while an editor split is open; releases the wait in `H.command_impl`.
H.skip_sync = false
--- Modifiers of the `:Jj` that opened the editor, read back by `HueyJj._edit`.
H.editor_mods = ''
H.root_cache = {}

--- jj subcommand behind any leading global flags, with aliases resolved and
--- container subcommands joined into their two-word name (`op log` ->
--- `operation log`). Drives output routing and the split's filetype.
--- @param args string[]
--- @return string?
H.parse_subcommand = function(args)
  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == '--' then return nil end
    -- `--color=never` carries its value; `--color never` takes the next arg
    local name, inline = arg:match('^(%-%-?[^=]+)=(.*)$')
    local takes_value = global_flags[name or arg]
    if takes_value == nil then break end
    i = i + ((takes_value and inline == nil) and 2 or 1)
  end

  local sub = args[i]
  if sub == nil or sub:find('^%-') ~= nil then return nil end
  sub = aliases[sub] or sub

  local word = args[i + 1] or '-'
  if containers[sub] and word:find('^%-') == nil then return sub .. ' ' .. word end
  return sub
end

--- jj rejects a repeated `--color`/`--no-pager`, so inject only what the user
--- did not already pass.
--- @param args string[]
--- @return string[]
H.global_prefix = function(args)
  local seen = {}
  for _, arg in ipairs(args) do
    if arg == '--' then break end
    seen[arg:match('^([^=]+)')] = true
  end

  local res = {}
  if not seen['--no-pager'] then table.insert(res, '--no-pager') end
  if not seen['--color'] then table.insert(res, '--color=never') end
  return res
end

--- Expands cmdline specials in one argument. Narrower than 'mini.git', which
--- expands every argument and so mangles things like `-m fix\ #123`.
--- @param x string
--- @return string
H.expandcmd = function(x)
  -- jj resolves relative paths against its own cwd, which is the workspace
  -- root rather than Nvim's cwd
  if x == '%' then return vim.fn.expand('%:p') end
  if x:find('^[%%#<~]') == nil then return x end
  local ok, res = pcall(vim.fn.expandcmd, x)
  return ok and res or x
end

--- jj workspace holding the current buffer, else Nvim's cwd. Cached because
--- `jj root` costs ~10ms and this runs on every completion keystroke.
--- @return string
H.command_cwd = function()
  local name = vim.api.nvim_buf_get_name(0)
  local is_file = name ~= '' and vim.bo.buftype == ''
  local dir = is_file and vim.fs.dirname(name) or vim.fn.getcwd()
  local cached = H.root_cache[dir]
  if cached == nil then
    cached = H.workspace_root(dir) or false
    H.root_cache[dir] = cached
  end
  return cached or vim.fn.getcwd()
end

--- @param mods string already-expanded command modifiers
--- @return boolean
H.is_silent = function(mods)
  return mods:find('silent') ~= nil and mods:find('unsilent') == nil
end

--- Command modifiers guaranteed to name a split, plus whether the caller had
--- already asked for one. Ports 'mini.git's `command.split = "auto"`: reuse the
--- tabpage while it holds only jj output, otherwise take a new one.
--- @param mods string
--- @return string mods, boolean was_explicit
H.split_mods = function(mods)
  if mods:find('vertical') or mods:find('horizontal') or mods:find('tab') then
    return mods, true
  end

  for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf_name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win_id))
    local is_normal = vim.api.nvim_win_get_config(win_id).relative == ''
    local is_jj = buf_name:find('^jj://%d+/') ~= nil
    if is_normal and not is_jj then return 'tab ' .. mods, false end
  end
  return 'vertical ' .. mods, false
end

--- Scratch window/buffer lifecycle: closing either wipes both and runs
--- `cleanup`. Ported from 'mini.git's `H.define_minigit_window()`.
--- @param cleanup function?
H.define_window = function(cleanup)
  local buf_id = vim.api.nvim_get_current_buf()
  local win_id = vim.api.nvim_get_current_win()
  vim.bo.swapfile, vim.bo.buflisted = false, false

  local au_id
  local finish = function(data)
    local is_target = data.buf == buf_id
      or (data.event == 'WinClosed' and tonumber(data.match) == win_id)
    if not is_target then return end

    pcall(vim.api.nvim_del_autocmd, au_id)
    pcall(vim.api.nvim_win_close, win_id, true)
    local force = { force = true }
    vim.schedule(function() pcall(vim.api.nvim_buf_delete, buf_id, force) end)
    if vim.is_callable(cleanup) then vim.schedule(cleanup) end
  end

  -- `nested` so other plugins still see the window events this triggers
  local events = { 'WinClosed', 'BufDelete', 'BufWipeout', 'VimLeave' }
  local opts = { nested = true, callback = finish, desc = 'Cleanup jj window' }
  au_id = vim.api.nvim_create_autocmd(events, opts)
end

--- jj's default diff is its color-words format rather than a unified diff, and
--- its `log` graph matches no filetype. So sniff for git-format output, let
--- `file show` be detected from the buffer name, and leave the rest unset.
--- @param buf_id number
--- @param lines string[]
--- @param subcommand string?
--- @return string?
H.split_filetype = function(buf_id, lines, subcommand)
  if (lines[1] or ''):find('^diff %-%-git') ~= nil then return 'diff' end
  if subcommand == 'file show' then return vim.filetype.match({ buf = buf_id }) end
  return nil
end

--- @param mods string
--- @param lines string[]
--- @param subcommand string?
--- @param name string
H.show_in_split = function(mods, lines, subcommand, name)
  vim.cmd(H.split_mods(mods) .. ' split')
  local win_id = vim.api.nvim_get_current_win()

  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf_id, ('jj://%d/%s'):format(buf_id, name))
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf_id)
  H.define_window()

  -- set once the buffer is in a window, so `FileType` autocommands can reach
  -- window-local options
  local filetype = H.split_filetype(buf_id, lines, subcommand)
  if filetype == nil or filetype == '' then
    vim.wo[win_id].foldlevel = 999
  else
    vim.bo[buf_id].filetype = filetype
  end
end

--- @param mods string
--- @param stdout string
--- @param args string[]
--- @param subcommand string?
H.show_stdout = function(mods, stdout, args, subcommand)
  if stdout == '' then return end

  local _, is_explicit_split = H.split_mods(mods)
  if not (is_explicit_split or info_subcommands[subcommand]) then
    return vim.notify(stdout, vim.log.levels.INFO)
  end
  -- named from the user's args so the injected global flags stay out of it
  local name = 'jj ' .. table.concat(args, ' ')
  H.show_in_split(mods, vim.split(stdout, '\n'), subcommand, name)
end

--- @param input table per `:h nvim_create_user_command()`
--- @param args string[] expanded user arguments
--- @param done table box flipped once the job finishes
--- @return function
H.on_exit = function(input, args, done)
  local subcommand = H.parse_subcommand(args)
  return vim.schedule_wrap(function(out)
    done.value = true
    local stdout = (out.stdout or ''):gsub('%s+$', '')
    local stderr = (out.stderr or ''):gsub('%s+$', '')

    if out.code ~= 0 then
      local msg = stderr .. (stdout == '' and '' or '\n' .. stdout)
      vim.notify(msg, vim.log.levels.ERROR)
    elseif not H.is_silent(input.mods) then
      -- every jj mutation reports the new working copy on stderr; that is
      -- normal chatter, not a warning
      if stderr ~= '' then vim.notify(stderr, vim.log.levels.INFO) end
      H.show_stdout(input.mods, stdout, args, subcommand)
    end

    -- a failed command can still have touched the working copy
    vim.cmd('silent! checktime')
  end)
end

--- @param args string[]
--- @param subcommand string?
--- @return boolean
H.needs_diff_editor = function(args, subcommand)
  if diff_editor_subcommands[subcommand] then return true end
  return vim.tbl_contains(args, '-i') or vim.tbl_contains(args, '--interactive')
end

--- @param mods string
--- @param args string[]
H.run_in_terminal = function(mods, args)
  local quoted = table.concat(vim.tbl_map(vim.fn.shellescape, args), ' ')
  vim.cmd(H.split_mods(mods) .. ' split')
  -- separate `:cmd`: `:terminal` swallows the rest of the line, `|` included
  vim.cmd('terminal jj ' .. quoted)
end

--- Bridges jj's `ui.editor` back into this instance: jj runs a throwaway
--- headless Nvim which RPCs `HueyJj._edit` here and blocks until the split is
--- closed, which is jj's signal that editing is done.
--- @return string? `ui.editor=[...]` for `--config`, nil without an RPC server
H.ensure_editor = function()
  local server = vim.v.servername
  if server == '' then server = vim.fn.serverstart() end
  if server == nil or server == '' then return nil end

  if H.editor_script == nil or vim.fn.filereadable(H.editor_script) == 0 then
    H.editor_script = vim.fn.tempname()
    local connect = 'local chan = vim.fn.sockconnect("pipe", %s, { rpc = true })'
    vim.fn.writefile({
      'lua << EOF',
      connect:format(vim.inspect(server)),
      'local ins = vim.inspect',
      'local cmd = string.format("HueyJj._edit(%s, %s)",'
        .. ' ins(vim.fn.argv(0)), ins(vim.v.servername))',
      -- `rpcrequest` blocks, which is what keeps jj waiting
      'vim.rpcrequest(chan, "nvim_exec_lua", cmd, {})',
      'EOF',
    }, H.editor_script)
  end

  -- a TOML array rather than 'mini.git's `GIT_EDITOR` string: no shell
  -- word-splitting, so a `progpath` containing spaces survives
  local argv = { vim.v.progpath, '--clean', '--headless', '-u', H.editor_script }
  return 'ui.editor=' .. vim.json.encode(argv)
end

--- @param input table per `:h nvim_create_user_command()`
H.command_impl = function(input)
  local args = vim.tbl_map(H.expandcmd, input.fargs)
  local subcommand = H.parse_subcommand(args)
  if H.needs_diff_editor(args, subcommand) then
    return H.run_in_terminal(input.mods, args)
  end

  local command = { 'jj' }
  vim.list_extend(command, H.global_prefix(args))
  local editor = H.ensure_editor()
  if editor ~= nil then vim.list_extend(command, { '--config', editor }) end
  vim.list_extend(command, args)

  H.editor_mods = input.mods
  local done = { value = false }
  local opts = { cwd = H.command_cwd(), text = true }
  vim.system(command, opts, H.on_exit(input, args, done))

  if input.bang then return end
  -- `vim.wait` rather than `:wait()`, so scheduled callbacks -- the editor
  -- bridge's RPC among them -- still run while blocking
  vim.wait(H.timeout, function() return done.value or H.skip_sync end, 10)
end

--- Words after `:Jj` up to the cursor, with the word being completed last. It
--- may be empty; jj's completion engine needs that trailing element regardless.
--- @param cmdline string
--- @param cursorpos number
--- @return string[]
H.complete_words = function(cmdline, cursorpos)
  -- also skips any command modifiers and the bang
  local _, cmd_end = cmdline:sub(1, cursorpos):find('Jj!?%s')
  if cmd_end == nil then return { '' } end

  local rest = cmdline:sub(cmd_end + 1, cursorpos)
  local words, cur, i = {}, nil, 1
  while i <= #rest do
    local char = rest:sub(i, i)
    if char == '\\' then
      cur, i = (cur or '') .. rest:sub(i + 1, i + 1), i + 2
    elseif char == ' ' or char == '\t' then
      if cur ~= nil then table.insert(words, cur) end
      cur, i = nil, i + 1
    else
      cur, i = (cur or '') .. char, i + 1
    end
  end
  table.insert(words, cur or '')
  return words
end

--- Asks jj's own clap completion engine, which covers subcommands, flags,
--- revsets, bookmarks and paths. It does not snapshot the working copy, so
--- holding down <Tab> cannot churn `gen_diff_source()`'s reference text.
--- @param words string[]
--- @return string[]
H.complete_engine = function(words)
  local command = { 'jj', '--', 'jj' }
  vim.list_extend(command, words)
  local opts = { cwd = H.command_cwd(), text = true, env = { COMPLETE = 'fish' } }
  local ms = H.complete_timeout
  local run = function() return vim.system(command, opts):wait(ms) end
  local ok, out = pcall(run)
  if not ok or out.code ~= 0 then return {} end

  local res = {}
  for _, line in ipairs(vim.split(out.stdout, '\n')) do
    -- `value<TAB>description`
    local value = line:match('^([^\t]+)')
    -- re-escape, mirroring the unescaping in `H.complete_words()`
    if value ~= nil then table.insert(res, (value:gsub(' ', '\\ '))) end
  end
  return res
end

--- @param arglead string
--- @param cmdline string
--- @param cursorpos number
--- @return string[]
H.complete = function(arglead, cmdline, cursorpos)
  -- unfiltered: Nvim does not filter a function `complete`, and the engine has
  -- already filtered by the trailing word and returns full path prefixes
  local candidates = H.complete_engine(H.complete_words(cmdline, cursorpos))
  if #candidates > 0 then return candidates end
  local matches = function(x) return vim.startswith(x, arglead) end
  return vim.tbl_filter(matches, subcommands)
end

--- @private called over RPC by the editor bridge; see `H.ensure_editor()`
HueyJj._edit = function(path, servername)
  -- release `H.command_impl`'s wait so the split is usable
  H.skip_sync = true
  local cleanup = function()
    local ok, chan = pcall(vim.fn.sockconnect, 'pipe', servername, { rpc = true })
    if ok then pcall(vim.rpcnotify, chan, 'nvim_exec2', 'quitall!', {}) end
    H.skip_sync = false
  end

  vim.cmd(H.split_mods(H.editor_mods) .. ' split ' .. vim.fn.fnameescape(path))
  H.define_window(cleanup)
end

HueyJj.setup = function()
  _G.HueyJj = HueyJj
  -- `require` rather than the global so registration ignores plugin/ ordering
  require('mini.pick').registry.jj_hunks = function(local_opts)
    return HueyJj.pick_hunks(local_opts)
  end

  -- `bang` means async, as in 'mini.git': it skips the synchronous wait
  local opts = {
    bang = true,
    nargs = '+',
    complete = H.complete,
    desc = 'Execute a jj command',
  }
  vim.api.nvim_create_user_command('Jj', H.command_impl, opts)
end

--- @private exported for 'tests/test_jj.lua'
HueyJj.H = H

return HueyJj
