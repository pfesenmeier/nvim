-- module for picking diff hunks out of a jj revision
--
-- jj has no index, so the git staged/unstaged split maps onto revisions instead:
-- `@` (working copy commit) stands in for unstaged, `@-` for staged. Falls back to
-- `MiniExtra.pickers.git_hunks` when there is no jj workspace.
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
    vim.list_extend(command, { '--', ('root-file:"%s"'):format(relpath) })
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

HueyJj.setup = function()
  _G.HueyJj = HueyJj
  -- `require` rather than the global so registration ignores plugin/ ordering
  require('mini.pick').registry.jj_hunks = function(local_opts)
    return HueyJj.pick_hunks(local_opts)
  end
end

return HueyJj
