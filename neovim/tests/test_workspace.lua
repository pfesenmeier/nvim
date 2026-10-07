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
    _G.connected, _G.stop_current = {}, {}
    _G.ws.connect = function(name, stop)
      table.insert(_G.connected, name)
      -- `or false`: a nil hole would truncate the list on the way out
      table.insert(_G.stop_current, stop or false)
    end
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
local stop_current = function() return child.lua_get('_G.stop_current') end

--- `M.quit()` falls back to `:qa`, which would take the child down with it.
--- Record commands instead; only module code runs `vim.cmd` during a test.
local stub_cmd = function()
  child.lua('_G.cmds = {}; vim.cmd = function(c) table.insert(_G.cmds, c) end')
end
local cmds = function() return child.lua_get('_G.cmds') end

local servers = {}

--- Starts a real headless nvim as workspace `name`'s server, with `vim.g.tag`
--- set to `name` and each of `bufs` added (listed unless `listed = false`).
--- @param root string from `setup_live()`
--- @param bufs { name: string, listed: boolean? }[]?
--- @return integer chan RPC channel to the server
local start_server = function(root, name, bufs)
  local sock = root .. '/servers/' .. name .. '.sock'
  local job = vim.fn.jobstart({ 'nvim', '--clean', '--headless', '--listen', sock })
  local chan
  local up = vim.wait(5000, function()
    local ok, c = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
    if ok and c ~= 0 then chan = c end
    return chan ~= nil
  end, 20)
  assert(up, 'server did not start: ' .. sock)
  table.insert(servers, { job = job, chan = chan })
  vim.rpcrequest(
    chan,
    'nvim_exec_lua',
    [[
      local name, bufs = ...
      vim.g.tag = name
      for _, b in ipairs(bufs) do
        vim.bo[vim.fn.bufadd(b.name)].buflisted = b.listed ~= false
      end
    ]],
    { name, bufs or {} }
  )
  return chan
end

local stop_servers = function()
  for _, s in ipairs(servers) do
    pcall(vim.rpcnotify, s.chan, 'nvim_command', 'qa!')
    pcall(vim.fn.chanclose, s.chan)
    pcall(vim.fn.jobstop, s.job)
  end
  servers = {}
end

--- Like `setup_ws()`, but `status` is real so live servers are probed. Only
--- `connect` is stubbed, and `MiniPick.start` records its source in `_G.source`.
--- @return string root
local setup_live = function()
  local root, spec = new_workspaces()
  child.lua(
    [[
    local spec, server_dir = ...
    _G.ws = require('workspace')
    _G.ws.setup({ workspaces = spec, server_dir = server_dir })
    _G.connected = {}
    _G.ws.connect = function(name) table.insert(_G.connected, name) end
    _G.MiniPick = { start = function(o) _G.source = o.source end }
  ]],
    { spec, root .. '/servers' }
  )
  return root
end

--- Makes the child itself answer as workspace `name`, the way a workspace
--- server sees its own socket.
local child_listen_as = function(root, name)
  child.fn.serverstart(root .. '/servers/' .. name .. '.sock')
end

--- `{ ws, name }` of every item the picker was given, in order.
local picked = function()
  return child.lua_get([[vim.tbl_map(
    function(i) return { i.ws, i.name } end,
    _G.source.items
  )]])
end

--- Confirms the item whose buffer name is `name`, then lets `vim.schedule` run.
local choose = function(name)
  child.lua(
    [[
    local name = ...
    for _, i in ipairs(_G.source.items) do
      if i.name == name then return _G.source.choose(i) end
    end
    error('no item named ' .. name)
  ]],
    { name }
  )
  child.poke_eventloop()
end

local T = new_set({
  hooks = {
    pre_case = child.setup,
    post_case = function()
      stop_servers()
      cleanup_temp_roots()
    end,
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

T['M.quit()'] = new_set()

T['M.quit()']['connects to the next running, stopping the current'] = function()
  -- alpha(cur) beta[stopped] gamma delta[stopped]
  setup_ws({ alpha = true, gamma = true }, 'alpha')
  child.lua('_G.ws.quit()')
  eq(connected(), { 'gamma' })
  eq(stop_current(), { true })
end

T['M.quit()']['wraps to the first running'] = function()
  setup_ws({ alpha = true, delta = true }, 'delta')
  child.lua('_G.ws.quit()')
  eq(connected(), { 'alpha' })
  eq(stop_current(), { true })
end

T['M.quit()']['ignores a count'] = function()
  setup_ws({ alpha = true, beta = true, gamma = true, delta = true }, 'alpha')
  -- `<Space>` rather than `<Leader>`: 'scripts/minimal_init.lua' sets no mapleader
  child.lua([[vim.keymap.set('n', '<Space>wq', '<Cmd>lua _G.ws.quit()<CR>')]])
  child.type_keys('3 wq')
  eq(connected(), { 'beta' })
end

T['M.quit()']['quits when it is the only running one'] = function()
  setup_ws({ beta = true }, 'beta')
  stub_cmd()
  child.lua('_G.ws.quit()')
  eq(cmds(), { 'qa' })
  eq(connected(), {})
end

T['M.quit()']['quits when none are running'] = function()
  setup_ws({}, 'beta')
  stub_cmd()
  child.lua('_G.ws.quit()')
  eq(cmds(), { 'qa' })
  eq(connected(), {})
end

T['M.quit()']['leaves a workspace whose server never started'] = function()
  setup_ws({ gamma = true }, 'alpha')
  child.lua('_G.ws.quit()')
  eq(connected(), { 'gamma' })
  eq(stop_current(), { true })
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

T['M.collect()'] = new_set()

T['M.collect()']['gathers from running servers in configured order'] = function()
  local root = setup_live()
  -- started out of order on purpose
  start_server(root, 'delta')
  start_server(root, 'beta')
  eq(child.lua_get('_G.ws.collect("return vim.g.tag")'), {
    { ws = 'beta', result = 'beta' },
    { ws = 'delta', result = 'delta' },
  })
end

T['M.collect()']['passes args to the chunk'] = function()
  local root = setup_live()
  start_server(root, 'beta')
  eq(
    child.lua_get([[_G.ws.collect('return vim.g.tag .. ...', { '!' })]]),
    { { ws = 'beta', result = 'beta!' } }
  )
end

T['M.collect()']['runs in-process for its own workspace'] = function()
  local root = setup_live()
  child_listen_as(root, 'alpha')
  child.g.tag = 'child'
  start_server(root, 'gamma')
  eq(child.lua_get('_G.ws.collect("return vim.g.tag")'), {
    { ws = 'alpha', result = 'child' },
    { ws = 'gamma', result = 'gamma' },
  })
end

T['M.pick_buffers()'] = new_set()

T['M.pick_buffers()']['lists buffers from every running workspace'] = function()
  local root = setup_live()
  local a, b = root .. '/beta/a.txt', root .. '/delta/b.txt'
  start_server(root, 'beta', { { name = a } })
  start_server(root, 'delta', { { name = b } })
  child.lua('_G.ws.pick_buffers()')
  eq(picked(), { { 'beta', a }, { 'delta', b } })
  -- rows lead with the workspace
  eq(child.lua_get('_G.source.items[1].text'):match('^%S+'), 'beta')
end

T['M.pick_buffers()']['filters names by Lua pattern'] = function()
  local root = setup_live()
  local term = 'term://' .. root .. '/beta//123:claude'
  start_server(root, 'beta', {
    { name = term },
    { name = root .. '/beta/claude-notes.md' },
    { name = root .. '/beta/other.txt' },
  })
  child.lua('_G.ws.pick_buffers(...)', { '^term://.*:claude' })
  eq(picked(), { { 'beta', term } })
end

T['M.pick_buffers()']['skips unlisted buffers'] = function()
  local root = setup_live()
  local listed = root .. '/beta/listed.txt'
  start_server(root, 'beta', {
    { name = listed },
    { name = root .. '/beta/hidden.txt', listed = false },
  })
  child.lua('_G.ws.pick_buffers()')
  eq(picked(), { { 'beta', listed } })
end

T['M.pick_buffers()']['opens a remote buffer in its server, then connects'] = function()
  local root = setup_live()
  local a, b = root .. '/beta/a.txt', root .. '/beta/b.txt'
  local chan = start_server(root, 'beta', { { name = a }, { name = b } })
  child.lua('_G.ws.pick_buffers()')
  choose(b)
  eq(vim.rpcrequest(chan, 'nvim_eval', 'bufname()'), b)
  eq(connected(), { 'beta' })
end

T['M.pick_buffers()']['opens a local buffer without connecting'] = function()
  local root = setup_live()
  child_listen_as(root, 'alpha')
  local path = root .. '/alpha/here.txt'
  child.lua('vim.bo[vim.fn.bufadd(...)].buflisted = true', { path })
  child.lua('_G.ws.pick_buffers()')
  choose(path)
  eq(child.api.nvim_buf_get_name(0), path)
  eq(connected(), {})
end

return T
