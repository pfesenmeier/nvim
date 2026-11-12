local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local project_names = { 'alpha', 'beta', 'gamma', 'delta' }

local temp_roots = {}
--- Real directories, so `M.current_index()` can resolve a cwd against them,
--- listed in a store file at `<root>/projects.json`.
local new_projects = function()
  local root = vim.fn.tempname()
  local spec = {}
  for _, name in ipairs(project_names) do
    local path = root .. '/' .. name
    vim.fn.mkdir(path, 'p')
    spec[#spec + 1] = { name = name, path = path }
  end
  vim.fn.mkdir(root .. '/elsewhere', 'p')
  vim.fn.writefile({ vim.json.encode(spec) }, root .. '/projects.json')
  table.insert(temp_roots, root)
  return root
end

--- Options for `setup()` that read the store of `new_projects()`, with nothing
--- pinned so the list is exactly `project_names`.
local setup_opts = function(root)
  return {
    store = root .. '/projects.json',
    pinned = {},
    server_dir = root .. '/servers',
  }
end

local cleanup_temp_roots = function()
  for _, root in ipairs(temp_roots) do
    vim.fn.delete(root, 'rf')
  end
  temp_roots = {}
end

--- Loads the module in the child with a synthetic project list, stubbing
--- `status` (so no sockets are probed) and `connect` (so no `:connect` runs).
--- @param running table<string, boolean> which projects report 'running'
--- @param cwd string? directory to chdir into first
local setup_ws = function(running, cwd)
  local root = new_projects()
  child.lua(
    [[
    local o, running = ...
    _G.projects = require('huey.projects')
    _G.projects.setup(o)
    _G.projects.status = function(name) return running[name] and 'running' or 'stopped' end
    _G.connected, _G.stop_current = {}, {}
    _G.projects.connect = function(name, stop)
      table.insert(_G.connected, name)
      -- `or false`: a nil hole would truncate the list on the way out
      table.insert(_G.stop_current, stop or false)
    end
  ]],
    { setup_opts(root), running }
  )
  if cwd ~= nil then child.fn.chdir(root .. '/' .. cwd) end
  return root
end

local bracketed = function(direction, o)
  child.lua('_G.projects.bracketed(...)', { direction, o or {} })
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

--- Starts a real headless nvim as project `name`'s server, with `vim.g.tag`
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
  local root = new_projects()
  child.lua(
    [[
    _G.projects = require('huey.projects')
    _G.projects.setup(...)
    _G.connected = {}
    _G.projects.connect = function(name) table.insert(_G.connected, name) end
    _G.MiniPick = {
      start = function(o) _G.source = o.source end,
      -- inactive, so the bots picker's refresh timer stops on its first tick
      is_picker_active = function() return false end,
    }
  ]],
    { setup_opts(root) }
  )
  return root
end

--- Makes the child itself answer as project `name`, the way a project
--- server sees its own socket.
local child_listen_as = function(root, name)
  child.fn.serverstart(root .. '/servers/' .. name .. '.sock')
end

--- `{ project, name }` of every item the picker was given, in order.
local picked = function()
  return child.lua_get([[vim.tbl_map(
    function(i) return { i.project, i.name } end,
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
  eq(child.lua_get('_G.projects.names()'), project_names)
end

T['M.names()']['has no `home` entry'] = function()
  setup_ws({})
  eq(child.lua_get('vim.tbl_contains(_G.projects.names(), "home")'), false)
end

--- Loads the module with `pinned(root)` as its pinned projects.
local setup_pinned = function(pinned)
  local root = new_projects()
  local o = setup_opts(root)
  o.pinned = pinned(root)
  child.lua('_G.projects = require("huey.projects"); _G.projects.setup(...)', { o })
end

T['M.names()']['lists pinned projects first'] = function()
  setup_pinned(
    function(root) return { { name = 'pin', path = root .. '/elsewhere' } } end
  )
  eq(
    child.lua_get('_G.projects.names()'),
    { 'pin', 'alpha', 'beta', 'gamma', 'delta' }
  )
end

T['M.names()']['skips a stored path that is already pinned'] = function()
  setup_pinned(
    function(root) return { { name = 'pinned-beta', path = root .. '/beta' } } end
  )
  eq(
    child.lua_get('_G.projects.names()'),
    { 'pinned-beta', 'alpha', 'gamma', 'delta' }
  )
end

T['M.names()']['is empty without a store file'] = function()
  child.lua(
    'require("huey.projects").setup(...)',
    { { store = vim.fn.tempname(), pinned = {} } }
  )
  eq(child.lua_get('require("huey.projects").names()'), {})
end

T['M.add()'] = new_set()

--- Stored projects as written to disk.
local stored = function(root)
  return vim.json.decode(
    table.concat(vim.fn.readfile(root .. '/projects.json'), '\n')
  )
end

T['M.add()']['appends the folder to the store'] = function()
  local root = setup_ws({})
  vim.fn.mkdir(root .. '/new', 'p')
  eq(child.lua_get('_G.projects.add(...)', { root .. '/new' }), 'new')
  eq(
    child.lua_get('_G.projects.names()'),
    { 'alpha', 'beta', 'gamma', 'delta', 'new' }
  )
  eq(stored(root)[5], { name = 'new', path = root .. '/new' })
end

T['M.add()']['prefixes the parent folder when the name is taken'] = function()
  local root = setup_ws({})
  vim.fn.mkdir(root .. '/other/alpha', 'p')
  eq(
    child.lua_get('_G.projects.add(...)', { root .. '/other/alpha' }),
    'other-alpha'
  )
end

T['M.add()']['does not add a path twice'] = function()
  local root = setup_ws({})
  -- trailing slash, as a picker or `:ProjectAdd` might give it
  eq(child.lua_get('_G.projects.add(...)', { root .. '/beta/' }), 'beta')
  eq(#stored(root), 4)
end

T['M.add()']['sees projects another server added'] = function()
  local root = setup_ws({})
  -- what a second server's `add()` leaves on disk
  local list = stored(root)
  list[#list + 1] = { name = 'elsewhere', path = root .. '/elsewhere' }
  vim.fn.writefile({ vim.json.encode(list) }, root .. '/projects.json')
  eq(child.lua_get('_G.projects.names()')[5], 'elsewhere')
end

T['M.current_index()'] = new_set()

T['M.current_index()']['resolves cwd to its position'] = function()
  setup_ws({}, 'gamma')
  eq(child.lua_get('_G.projects.current_index()'), 3)
end

T['M.current_index()']['is nil outside any project'] = function()
  setup_ws({}, 'elsewhere')
  eq(child.lua_get('_G.projects.current_index()'), vim.NIL)
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
  child.lua(
    [[vim.keymap.set('n', ']w', "<Cmd>lua _G.projects.bracketed('forward')<CR>")]]
  )
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

T['M.bracketed()']['steps off a stopped current project'] = function()
  -- the TUI can sit in a project directory whose server was never spawned
  setup_ws({ gamma = true }, 'alpha')
  bracketed('forward')
  eq(connected(), { 'gamma' })
end

T['M.quit()'] = new_set()

T['M.quit()']['connects to the next running, stopping the current'] = function()
  -- alpha(cur) beta[stopped] gamma delta[stopped]
  setup_ws({ alpha = true, gamma = true }, 'alpha')
  child.lua('_G.projects.quit()')
  eq(connected(), { 'gamma' })
  eq(stop_current(), { true })
end

T['M.quit()']['wraps to the first running'] = function()
  setup_ws({ alpha = true, delta = true }, 'delta')
  child.lua('_G.projects.quit()')
  eq(connected(), { 'alpha' })
  eq(stop_current(), { true })
end

T['M.quit()']['ignores a count'] = function()
  setup_ws({ alpha = true, beta = true, gamma = true, delta = true }, 'alpha')
  -- `<Space>` rather than `<Leader>`: 'scripts/minimal_init.lua' sets no mapleader
  child.lua([[vim.keymap.set('n', '<Space>wq', '<Cmd>lua _G.projects.quit()<CR>')]])
  child.type_keys('3 wq')
  eq(connected(), { 'beta' })
end

T['M.quit()']['quits when it is the only running one'] = function()
  setup_ws({ beta = true }, 'beta')
  stub_cmd()
  child.lua('_G.projects.quit()')
  eq(cmds(), { 'qa' })
  eq(connected(), {})
end

T['M.quit()']['quits when none are running'] = function()
  setup_ws({}, 'beta')
  stub_cmd()
  child.lua('_G.projects.quit()')
  eq(cmds(), { 'qa' })
  eq(connected(), {})
end

T['M.quit()']['leaves a project whose server never started'] = function()
  setup_ws({ gamma = true }, 'alpha')
  child.lua('_G.projects.quit()')
  eq(connected(), { 'gamma' })
  eq(stop_current(), { true })
end

-- `alpha` (index 1) must be running here: it is the only arrangement where a
-- start state of 0 differs from 1, which is what pins the `or 0` fallback.
T['M.bracketed()']['starts from the edges outside any project'] = new_set({
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
  eq(child.lua_get('_G.projects.collect("return vim.g.tag")'), {
    { project = 'beta', result = 'beta' },
    { project = 'delta', result = 'delta' },
  })
end

T['M.collect()']['passes args to the chunk'] = function()
  local root = setup_live()
  start_server(root, 'beta')
  eq(
    child.lua_get([[_G.projects.collect('return vim.g.tag .. ...', { '!' })]]),
    { { project = 'beta', result = 'beta!' } }
  )
end

T['M.collect()']['runs in-process for its own project'] = function()
  local root = setup_live()
  child_listen_as(root, 'alpha')
  child.g.tag = 'child'
  start_server(root, 'gamma')
  eq(child.lua_get('_G.projects.collect("return vim.g.tag")'), {
    { project = 'alpha', result = 'child' },
    { project = 'gamma', result = 'gamma' },
  })
end

-- Real terminal buffers ('buftype' cannot be set to 'terminal' by hand), with
-- `HueyTerm` stubbed to read icons from `_G.icons` and bots from `_G.bots` so a
-- test can change them.
local add_bot_code = [[
  local icon, title, bot = ...
  -- nil args before a non-nil one arrive over RPC as vim.NIL
  if icon == vim.NIL then icon = nil end
  if title == vim.NIL then title = nil end
  _G.icons, _G.bots = _G.icons or {}, _G.bots or {}
  _G.HueyTerm = _G.HueyTerm or {
    get_icon = function(b) return _G.icons[b] end,
    is_bot = function(b) return _G.bots[b] == true end,
  }
  vim.cmd.enew()
  vim.fn.jobstart({ 'sleep', '30' }, { term = true })
  local b = vim.api.nvim_get_current_buf()
  _G.icons[b] = icon
  _G.bots[b] = bot
  if title then vim.b[b].term_title = title end
  return { bufnr = b, name = vim.api.nvim_buf_get_name(b) }
]]

--- Adds a terminal to server `chan` (or the child when nil) with status `icon`
--- (none when nil) and, when given, terminal `title`. `bot` marks it as having
--- reported progress before.
--- @return { bufnr: integer, name: string }
local add_bot = function(chan, icon, title, bot)
  if chan then
    return vim.rpcrequest(chan, 'nvim_exec_lua', add_bot_code, { icon, title, bot })
  end
  return child.lua(add_bot_code, { icon, title, bot })
end

local set_icon = function(chan, bufnr, icon)
  vim.rpcrequest(
    chan,
    'nvim_exec_lua',
    '_G.icons[...] = select(2, ...)',
    { bufnr, icon }
  )
end

--- Text after the icon and project of every row the picker was given.
local row_details = function()
  return child.lua_get([[vim.tbl_map(
    function(i) return i.text:match('^%S+%s+%S+%s+(.*)$') end,
    _G.source.items
  )]])
end

--- Leading icon of every row the picker was given, in order.
local row_icons = function()
  return child.lua_get([[vim.tbl_map(
    function(i) return i.text:match('^(%S+)') end,
    _G.source.items
  )]])
end

T['M.pick_bots()'] = new_set()

T['M.pick_bots()']['lists terminals with a status from every running project'] = function()
  local root = setup_live()
  local beta = start_server(root, 'beta')
  local delta = start_server(root, 'delta')
  local working = add_bot(delta, '∿')
  add_bot(beta, nil) -- a terminal with no status
  local waiting = add_bot(beta, '⏸')
  child.lua('_G.projects.pick_bots()')
  eq(picked(), { { 'beta', waiting.name }, { 'delta', working.name } })
  eq(row_icons(), { '⏸', '∿' })
  eq(child.lua_get('_G.source.items[1].text'):match('^%S+%s+(%S+)'), 'beta')
end

T['M.pick_bots()']['lists a bot with no status as idle'] = function()
  local root = setup_live()
  local beta = start_server(root, 'beta')
  local working = add_bot(beta, '●', nil, true)
  local idle = add_bot(beta, nil, nil, true) -- it reported state 0
  child.lua('_G.projects.pick_bots()')
  eq(picked(), { { 'beta', working.name }, { 'beta', idle.name } })
  eq(row_icons(), { '●', '·' })
end

T['M.pick_bots()']['shows the terminal title without its state glyph'] = function()
  local root = setup_live()
  local beta = start_server(root, 'beta')
  add_bot(beta, '∿', '◐ pick_bots in project init.lua')
  add_bot(beta, '⏸', 'plain title')
  child.lua('_G.projects.pick_bots()')
  eq(row_details(), { 'pick_bots in project init.lua', 'plain title' })
end

T['M.pick_bots()']['falls back to the buffer name without a summary'] = function()
  local root = setup_live()
  local beta = start_server(root, 'beta')
  local untitled = add_bot(beta, '∿') -- title is the default `term://` name
  local fresh = add_bot(beta, '⏸', '✳ Claude Code')
  child.lua('_G.projects.pick_bots()')
  eq(row_details(), { untitled.name, fresh.name })
end

T['M.pick_bots()']['skips a server without HueyTerm'] = function()
  local root = setup_live()
  start_server(root, 'beta') -- `--clean`, so no HueyTerm
  local delta = start_server(root, 'delta')
  local bot = add_bot(delta, '∿')
  child.lua('_G.projects.pick_bots()')
  eq(picked(), { { 'delta', bot.name } })
end

T['M.pick_bots()']['refreshes rows while open, only on change'] = function()
  local root = setup_live()
  local beta = start_server(root, 'beta')
  local bot = add_bot(beta, '∿')
  child.lua([[
    _G.MiniPick.is_picker_active = function() return true end
    _G.set_items = {}
    _G.MiniPick.set_picker_items = function(items) table.insert(_G.set_items, items) end
    _G.projects.pick_bots()
  ]])
  -- nothing changed: no reset of the picker
  vim.uv.sleep(1500)
  eq(child.lua_get('#_G.set_items'), 0)

  set_icon(beta, bot.bufnr, '⏸')
  eq(child.wait_for('#_G.set_items == 1'), true)
  eq(child.lua_get('_G.set_items[1][1].text'):match('^%S+'), '⏸')

  child.api.nvim_exec_autocmds('User', { pattern = 'MiniPickStop' })
  set_icon(beta, bot.bufnr, '●')
  vim.uv.sleep(1500)
  eq(child.lua_get('#_G.set_items'), 1)
end

T['M.pick_bots()']['opens a remote terminal in its server, then connects'] = function()
  local root = setup_live()
  local beta = start_server(root, 'beta')
  local first = add_bot(beta, '∿')
  add_bot(beta, '⏸') -- now current in beta
  child.lua('_G.projects.pick_bots()')
  choose(first.name)
  eq(vim.rpcrequest(beta, 'nvim_get_current_buf'), first.bufnr)
  eq(connected(), { 'beta' })
end

T['M.pick_bots()']['opens a local terminal without connecting'] = function()
  local root = setup_live()
  child_listen_as(root, 'alpha')
  local here = add_bot(nil, '∿')
  child.cmd('enew')
  child.lua('_G.projects.pick_bots()')
  choose(here.name)
  eq(child.api.nvim_get_current_buf(), here.bufnr)
  eq(connected(), {})
end

return T
