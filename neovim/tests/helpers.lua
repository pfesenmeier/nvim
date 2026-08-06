-- Shared test helpers, trimmed from 'mini.nvim/tests/helpers.lua'.
-- Loaded with `dofile('tests/helpers.lua')`, so tests must run from 'neovim/'.
local Helpers = {}

Helpers.expect = vim.deepcopy(MiniTest.expect)

Helpers.expect.match = MiniTest.new_expectation(
  'string matching',
  function(str, pattern) return str:find(pattern) ~= nil end,
  function(str, pattern)
    local fmt = 'Pattern: %s\nObserved string: %s'
    return string.format(fmt, vim.inspect(pattern), str)
  end
)

Helpers.expect.contains = MiniTest.new_expectation(
  'array containing element',
  function(arr, x) return vim.tbl_contains(arr, x) end,
  function(arr, x)
    local fmt = 'Element: %s\nObserved array: %s'
    return string.format(fmt, vim.inspect(x), vim.inspect(arr))
  end
)

Helpers.new_child_neovim = function()
  local child = MiniTest.new_child_neovim()

  child.setup = function()
    child.restart({ '-u', 'scripts/minimal_init.lua' })
    child.bo.readonly = false
  end

  child.set_lines = function(arr, start, finish)
    if type(arr) == 'string' then arr = vim.split(arr, '\n') end
    child.api.nvim_buf_set_lines(0, start or 0, finish or -1, false, arr)
  end

  child.get_lines = function(start, finish)
    return child.api.nvim_buf_get_lines(0, start or 0, finish or -1, false)
  end

  -- Poke child's event loop to make it up to date
  child.poke_eventloop = function() child.api.nvim_eval('1') end

  --- Block until `lua_expr` evaluates truthy in the child.
  --- Reference text arrives from a `vim.system` callback and hunks are computed
  --- on a *later* scheduled pass, so waiting on the observable beats sleeping.
  --- @param lua_expr string
  --- @param timeout number?
  --- @return boolean
  child.wait_for = function(lua_expr, timeout)
    local deadline = vim.uv.now() + (timeout or Helpers.get_time_const(5000))
    while vim.uv.now() < deadline do
      local truthy = child.lua_get('(' .. lua_expr .. ') and true or false')
      if truthy == true then return true end
      vim.uv.sleep(20)
      vim.uv.update_time()
    end
    return false
  end

  return child
end

Helpers.is_ci = function() return os.getenv('CI') ~= nil end

Helpers.get_time_const = function(delay)
  return (Helpers.is_ci() and 2 or 1) * delay
end

Helpers.skip_if_no_jj = function()
  if vim.fn.executable('jj') == 0 then MiniTest.skip('`jj` executable not found') end
end

--- Creates a throwaway jj repo whose `@-` holds `files` and whose `@` is empty.
--- A jj repo cannot be committed as a fixture inside this repo's own jj repo,
--- so integration cases build one per case and delete it afterwards.
--- @param files table<string, string[]> repo-relative path -> lines
--- @return string root
Helpers.new_jj_repo = function(files)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')

  local jj = function(...)
    local opts = { cwd = root, text = true }
    local out = vim.system({ 'jj', '--no-pager', ... }, opts):wait()
    if out.code ~= 0 then
      error(('jj %s: %s'):format(table.concat({ ... }, ' '), out.stderr))
    end
    return out.stdout
  end

  jj('git', 'init')
  for path, lines in pairs(files) do
    vim.fn.mkdir(vim.fs.dirname(root .. '/' .. path), 'p')
    vim.fn.writefile(lines, root .. '/' .. path)
  end
  jj('describe', '-m', 'base')
  jj('new')

  return root
end

--- Runs `jj` in `root` and returns stdout.
--- @param root string
--- @return string
Helpers.jj = function(root, ...)
  local opts = { cwd = root, text = true }
  local out = vim.system({ 'jj', '--no-pager', ... }, opts):wait()
  if out.code ~= 0 then
    error(('jj %s: %s'):format(table.concat({ ... }, ' '), out.stderr))
  end
  return out.stdout
end

--- Short change id of `revset`, used to prove `--keep-emptied` works.
--- @param root string
--- @param revset string
--- @return string
Helpers.change_id = function(root, revset)
  local t = 'change_id.short()'
  return vim.trim(Helpers.jj(root, 'log', '--no-graph', '-r', revset, '-T', t))
end

return Helpers
