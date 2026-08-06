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
    for i = ref_i, copy_until do table.insert(res, ref_lines[i]) end
    for i = h.buf_start, h.buf_start + h.buf_count - 1 do
      table.insert(res, buf_lines[i])
    end
    ref_i = copy_until + h.ref_count + 1
  end
  for i = ref_i, #ref_lines do table.insert(res, ref_lines[i]) end
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

HueyJj.setup = function()
  _G.HueyJj = HueyJj
  -- `require` rather than the global so registration ignores plugin/ ordering
  require('mini.pick').registry.jj_hunks = function(local_opts)
    return HueyJj.pick_hunks(local_opts)
  end
end

return HueyJj
