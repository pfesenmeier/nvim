local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local temp_roots = {}

--- Two real project dirs holding two real files each, so the index survives the
--- pruning that `write_index()` performs on the way out.
local new_projects = function()
  local root = vim.fn.tempname()
  local spec = {}
  for _, proj in ipairs({ 'one', 'two' }) do
    vim.fn.mkdir(root .. '/' .. proj, 'p')
    for _, name in ipairs({ 'a.lua', 'b.lua' }) do
      local path = root .. '/' .. proj .. '/' .. name
      vim.fn.writefile({ '-- ' .. name }, path)
      spec[proj .. '/' .. name] = path
    end
    spec[proj] = root .. '/' .. proj
  end
  table.insert(temp_roots, root)
  return root, spec
end

local cleanup_temp_roots = function()
  for _, root in ipairs(temp_roots) do
    vim.fn.delete(root, 'rf')
  end
  temp_roots = {}
end

--- Loads both modules in the child against a synthetic index.
---
--- `store.path` must point at a temp file: the default is the real
--- 'mini-visits-index' under `stdpath('data')`, which a test run would clobber.
--- `track.event = ''` stops buffer entries registering stray visits mid-test.
---
--- Index shape: 'one/a.lua' and 'two/a.lua' carry "core"; 'one/b.lua' carries
--- "other"; 'two/b.lua' carries "core" under *both* projects, so a cwd-scoped
--- clear has something to leave behind.
--- @param cwd string project to chdir into, 'one' or 'two'
local setup_visits = function(cwd)
  local root, p = new_projects()
  -- `[==[` delimiters: the index literal below contains `]]`, which would close
  -- a plain long string early.
  child.lua(
    [==[
    local p, store_path = ...
    _G.store_path = store_path
    require('mini.visits').setup({ store = { path = store_path }, track = { event = '' } })
    require('huey.visits').setup()

    local visit = function(labels) return { count = 5, latest = 100, labels = labels } end
    MiniVisits.set_index({
      [p.one] = {
        [p['one/a.lua']] = visit({ core = true }),
        [p['one/b.lua']] = visit({ other = true }),
        [p['two/b.lua']] = visit({ core = true }),
      },
      [p.two] = {
        [p['two/a.lua']] = visit({ core = true }),
        [p['two/b.lua']] = visit({ core = true }),
      },
    })
  ]==],
    { p, root .. '/index' }
  )
  child.fn.chdir(p[cwd])
  return p
end

--- Scripts the two prompts `clear_label` puts up.
--- @param label string|nil what `vim.ui.input` hands back; `nil` cancels
--- @param confirm boolean whether `vim.fn.confirm` returns "Yes"
local stub_prompts = function(label, confirm)
  child.lua(
    [[
    local label, confirm = ...
    _G.n_confirm = 0
    vim.ui.input = function(_, on_input) on_input(label) end
    vim.fn.confirm = function() _G.n_confirm = _G.n_confirm + 1; return confirm and 2 or 1 end
  ]],
    { label, confirm }
  )
end

--- As above, for a dismissed `vim.ui.input`. Separate because `nil` cannot be
--- sent through `child.lua` args: it arrives as `vim.NIL`, not `nil`.
local stub_cancelled_prompt = function()
  child.lua([[
    _G.n_confirm = 0
    vim.ui.input = function(_, on_input) on_input(nil) end
    vim.fn.confirm = function() _G.n_confirm = _G.n_confirm + 1; return 2 end
  ]])
end

local clear_label = function(cwd) child.lua('HueyVisits.clear_label(...)', { cwd }) end

--- Raw index entry for `path` under `cwd`.
local visit_data = function(cwd, path)
  local code = 'MiniVisits.get_index()[select(1, ...)][select(2, ...)]'
  return child.lua_get(code, { cwd, path })
end

--- Labels of `path` under `cwd`, as a sorted array so comparisons are stable.
local labels_of = function(cwd, path)
  return vim.fn.sort(vim.tbl_keys(visit_data(cwd, path).labels or {}))
end

local T = new_set({
  hooks = {
    pre_case = child.setup,
    post_case = cleanup_temp_roots,
    post_once = child.stop,
  },
})

T['clear_label()'] = new_set()

T['clear_label()']['removes the label from every project'] = function()
  local p = setup_visits('one')
  stub_prompts('core', true)
  clear_label('')

  eq(labels_of(p.one, p['one/a.lua']), {})
  eq(labels_of(p.two, p['two/a.lua']), {})
  eq(labels_of(p.one, p['two/b.lua']), {})
  eq(labels_of(p.two, p['two/b.lua']), {})
end

T['clear_label()']['leaves other labels alone'] = function()
  local p = setup_visits('one')
  stub_prompts('core', true)
  clear_label('')

  eq(labels_of(p.one, p['one/b.lua']), { 'other' })
end

T['clear_label()']['scopes to the current project when cwd is nil'] = function()
  local p = setup_visits('one')
  stub_prompts('core', true)
  clear_label(nil)

  eq(labels_of(p.one, p['one/a.lua']), {})
  -- Same file, still labeled under the project that was not cleared
  eq(labels_of(p.one, p['two/b.lua']), {})
  eq(labels_of(p.two, p['two/b.lua']), { 'core' })
  eq(labels_of(p.two, p['two/a.lua']), { 'core' })
end

T['clear_label()']['keeps visit data'] = function()
  local p = setup_visits('one')
  stub_prompts('core', true)
  clear_label('')

  local data = visit_data(p.one, p['one/a.lua'])
  eq(data.count, 5)
  eq(data.latest, 100)
  eq(data.labels, nil)
end

T['clear_label()']['does nothing when confirm is declined'] = function()
  local p = setup_visits('one')
  stub_prompts('core', false)
  clear_label('')

  eq(child.lua_get('_G.n_confirm'), 1)
  eq(labels_of(p.one, p['one/a.lua']), { 'core' })
end

T['clear_label()']['does not confirm an unknown label'] = function()
  local p = setup_visits('one')
  stub_prompts('nope', true)
  clear_label('')

  eq(child.lua_get('_G.n_confirm'), 0)
  eq(labels_of(p.one, p['one/a.lua']), { 'core' })
end

T['clear_label()']['is a no-op when the prompt is cancelled'] = function()
  local p = setup_visits('one')
  stub_cancelled_prompt()
  clear_label('')

  eq(child.lua_get('_G.n_confirm'), 0)
  eq(labels_of(p.one, p['one/a.lua']), { 'core' })
end

T['clear_label()']['persists the cleared index to disk'] = function()
  local p = setup_visits('one')
  stub_prompts('core', true)
  clear_label('')

  eq(child.lua_get('vim.fn.filereadable(_G.store_path)'), 1)
  -- Read back rather than trusting the in-session table: the point of the write
  -- is that a concurrently running Nvim cannot resurrect the labels on exit.
  local stored = child.lua_get('MiniVisits.read_index(_G.store_path)')
  eq(stored[p.one][p['one/a.lua']].labels, nil)
  eq(stored[p.one][p['one/b.lua']].labels, { other = true })
end

return T
