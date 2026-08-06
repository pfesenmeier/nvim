local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local ws_names = { 'alpha', 'beta', 'gamma', 'delta' }

local temp_roots = {}
--- Real directories, so `M.current_index()` can resolve a cwd against them.
local new_workspaces = function()
  local root = vim.fn.tempname()
  local spec = {}
  for _, name in ipairs(ws_names) do
    local path = root .. '/' .. name
    vim.fn.mkdir(path, 'p')
    spec[#spec + 1] = { name = name, path = path }
  end
  vim.fn.mkdir(root .. '/elsewhere', 'p')
  table.insert(temp_roots, root)
  return root, spec
end

local cleanup_temp_roots = function()
  for _, root in ipairs(temp_roots) do
    vim.fn.delete(root, 'rf')
  end
  temp_roots = {}
end

--- Loads the module in the child with a synthetic workspace list, stubbing
--- `status` (so no sockets are probed) and `connect` (so no `:connect` runs).
--- @param running table<string, boolean> which workspaces report 'running'
--- @param cwd string? directory to chdir into first
local setup_ws = function(running, cwd)
  local root, spec = new_workspaces()
  child.lua(
    [[
    local spec, server_dir, running = ...
    _G.ws = require('workspace')
    _G.ws.setup({ workspaces = spec, server_dir = server_dir })
    _G.ws.status = function(name) return running[name] and 'running' or 'stopped' end
    _G.connected = {}
    _G.ws.connect = function(name) table.insert(_G.connected, name) end
  ]],
    { spec, root .. '/servers', running }
  )
  if cwd ~= nil then child.fn.chdir(root .. '/' .. cwd) end
  return root
end

local bracketed = function(direction, o)
  child.lua('_G.ws.bracketed(...)', { direction, o or {} })
end
local connected = function() return child.lua_get('_G.connected') end

local T = new_set({
  hooks = {
    pre_case = child.setup,
    post_case = cleanup_temp_roots,
    post_once = child.stop,
  },
})

T['M.names()'] = new_set()

T['M.names()']['returns configured order'] = function()
  setup_ws({})
  eq(child.lua_get('_G.ws.names()'), ws_names)
end

T['M.names()']['has no `home` entry'] = function()
  setup_ws({})
  eq(child.lua_get('vim.tbl_contains(_G.ws.names(), "home")'), false)
end

T['M.current_index()'] = new_set()

T['M.current_index()']['resolves cwd to its position'] = function()
  setup_ws({}, 'gamma')
  eq(child.lua_get('_G.ws.current_index()'), 3)
end

T['M.current_index()']['is nil outside any workspace'] = function()
  setup_ws({}, 'elsewhere')
  eq(child.lua_get('_G.ws.current_index()'), vim.NIL)
end

T['M.bracketed()'] = new_set()

T['M.bracketed()']['skips stopped going forward'] = function()
  -- alpha(cur) beta[stopped] gamma delta[stopped]
  setup_ws({ alpha = true, gamma = true }, 'alpha')
  bracketed('forward')
  eq(connected(), { 'gamma' })
end

T['M.bracketed()']['skips stopped going backward'] = function()
  setup_ws({ alpha = true, delta = true }, 'delta')
  bracketed('backward')
  eq(connected(), { 'alpha' })
end

T['M.bracketed()']['wraps forward past the end'] = function()
  setup_ws({ alpha = true, delta = true }, 'delta')
  bracketed('forward')
  eq(connected(), { 'alpha' })
end

T['M.bracketed()']['wraps backward past the start'] = function()
  setup_ws({ alpha = true, delta = true }, 'alpha')
  bracketed('backward')
  eq(connected(), { 'delta' })
end

T['M.bracketed()']['respects `wrap = false`'] = function()
  setup_ws({ alpha = true, delta = true }, 'delta')
  bracketed('forward', { wrap = false })
  eq(connected(), {})
end

T['M.bracketed()']['goes to the first running'] = function()
  setup_ws({ beta = true, gamma = true, delta = true }, 'delta')
  bracketed('first')
  eq(connected(), { 'beta' })
end

T['M.bracketed()']['goes to the last running'] = function()
  setup_ws({ alpha = true, beta = true, gamma = true }, 'alpha')
  bracketed('last')
  eq(connected(), { 'gamma' })
end

T['M.bracketed()']['advances `n_times`'] = function()
  setup_ws({ alpha = true, beta = true, gamma = true, delta = true }, 'alpha')
  bracketed('forward', { n_times = 2 })
  eq(connected(), { 'gamma' })
end

T['M.bracketed()']['takes a count from `v:count1`'] = function()
  setup_ws({ alpha = true, beta = true, gamma = true, delta = true }, 'alpha')
  child.lua([[vim.keymap.set('n', ']w', "<Cmd>lua _G.ws.bracketed('forward')<CR>")]])
  child.type_keys('3]w')
  eq(connected(), { 'delta' })
end

T['M.bracketed()']['does nothing when alone'] = function()
  setup_ws({ beta = true }, 'beta')
  bracketed('forward')
  bracketed('backward')
  bracketed('first')
  bracketed('last')
  eq(connected(), {})
end

T['M.bracketed()']['does nothing when none are running'] = function()
  setup_ws({}, 'beta')
  bracketed('forward')
  eq(connected(), {})
end

T['M.bracketed()']['steps off a stopped current workspace'] = function()
  -- the TUI can sit in a workspace directory whose server was never spawned
  setup_ws({ gamma = true }, 'alpha')
  bracketed('forward')
  eq(connected(), { 'gamma' })
end

-- `alpha` (index 1) must be running here: it is the only arrangement where a
-- start state of 0 differs from 1, which is what pins the `or 0` fallback.
T['M.bracketed()']['starts from the edges outside any workspace'] = new_set({
  parametrize = { { 'forward', 'alpha' }, { 'backward', 'gamma' } },
}, {
  test = function(direction, want)
    setup_ws({ alpha = true, gamma = true }, 'elsewhere')
    bracketed(direction)
    eq(connected(), { want })
  end,
})

return T
