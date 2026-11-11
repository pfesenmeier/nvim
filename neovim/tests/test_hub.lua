local helpers = dofile('tests/helpers.lua')

local expect = helpers.expect
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local huey = vim.fn.fnamemodify('../bin/huey', ':p')
local children = { helpers.new_child_neovim(), helpers.new_child_neovim() }

--- A fresh socket per case, so a hub left over from one case never answers
--- the next. Children inherit it through the environment.
local new_sock = function()
  if vim.fn.has('win32') == 1 then
    return [[\\.\pipe\huey-test-]] .. vim.fn.getpid() .. '-' .. vim.uv.hrtime()
  end
  return vim.fn.tempname() .. '.sock'
end

local hub_job
local start_hub = function()
  hub_job = vim.fn.jobstart({ vim.v.progpath, '-l', huey, 'serve' })
  eq(
    vim.wait(5000, function()
      local p = vim.uv.new_pipe(false)
      local ok
      p:connect(vim.env.HUEY_SOCK, function(err)
        ok = not err
        p:close()
      end)
      vim.wait(200, function() return ok ~= nil end, 10)
      return ok
    end, 50),
    true
  )
end

--- Every agent the hub knows, from `huey list`.
--- @return table[]
local list = function()
  local res = vim.system({ vim.v.progpath, '-l', huey, 'list' }, { text = true }):wait()
  eq(res.code, 0)
  local agents = vim.json.decode(res.stdout)
  table.sort(agents, function(a, b) return a.workspace < b.workspace end)
  return agents
end

--- Waits until `huey list` shows `n` agents.
--- @param n integer
--- @return table[]
local wait_list = function(n)
  local agents
  vim.wait(5000, function()
    agents = list()
    return #agents == n
  end, 100)
  return agents
end

local temp_dirs = {}

--- Starts `child` in its own folder (the workspace name), connects it to the
--- hub, and runs a terminal that reports `body`.
--- @param child table
--- @param name string folder, and so workspace, name
--- @param body string OSC 7501 record
local start_agent = function(child, name, body)
  local dir = vim.fn.tempname() .. '/' .. name
  vim.fn.mkdir(dir, 'p')
  table.insert(temp_dirs, vim.fs.dirname(dir))
  child.setup()
  child.fn.chdir(dir)
  child.lua(
    [[
    require('huey.term').setup()
    require('huey.hub.client').setup()
    vim.fn.jobstart({ 'sh', '-c', ... }, { term = true })
  ]],
    { ([[printf '\033]7501;%s\033\\'; sleep 30]]):format(body) }
  )
end

local T = new_set({
  hooks = {
    pre_case = function()
      vim.env.HUEY_SOCK = new_sock()
      vim.env.HUEY_IDLE_MS = '500'
    end,
    post_case = function()
      for _, child in ipairs(children) do
        child.stop()
      end
      if hub_job then vim.fn.jobstop(hub_job) end
      hub_job = nil
      for _, dir in ipairs(temp_dirs) do
        vim.fn.delete(dir, 'rf')
      end
      temp_dirs = {}
    end,
  },
})

T['lists agents from every nvim'] = function()
  start_hub()
  local title = vim.base64.encode('Fix the parser')
  start_agent(children[1], 'alpha', 'state=working:progress=50:title=' .. title)
  start_agent(children[2], 'beta', 'state=blocked:kind=permission')

  local agents = wait_list(2)
  eq(#agents, 2)
  eq(
    { agents[1].workspace, agents[1].state, agents[1].progress, agents[1].title },
    { 'alpha', 'working', 50, 'Fix the parser' }
  )
  eq({ agents[2].workspace, agents[2].state, agents[2].kind }, { 'beta', 'blocked', 'permission' })
  eq(agents[1].server, children[1].fn.eval('v:servername'))
end

T['drops the agents of an nvim that goes away'] = function()
  start_hub()
  start_agent(children[1], 'alpha', 'state=working')
  start_agent(children[2], 'beta', 'state=idle')
  eq(#wait_list(2), 2)

  children[2].stop()
  local agents = wait_list(1)
  eq(#agents, 1)
  eq(agents[1].workspace, 'alpha')
end

T['drops an agent whose buffer is wiped'] = function()
  start_hub()
  start_agent(children[1], 'alpha', 'state=working')
  eq(#wait_list(1), 1)

  children[1].lua('vim.cmd.bwipeout({ bang = true })')
  eq(#wait_list(0), 0)
end

--- Reports `status` for a new buffer in `child` straight to the hub, as its
--- client would, without a terminal in between.
--- @param child table
--- @param status table
--- @return integer buf
local fake_agent = function(child, status)
  return child.lua(
    [[
    local proto = require('huey.hub.proto')
    local buf = vim.api.nvim_create_buf(true, true)
    local pipe = vim.uv.new_pipe(false)
    local ok
    pipe:connect(vim.env.HUEY_SOCK, function(err) ok = not err end)
    vim.wait(2000, function() return ok ~= nil end, 10)
    _G.fake_pipes = _G.fake_pipes or {}
    table.insert(_G.fake_pipes, pipe)
    local now = os.time()
    local msg = vim.tbl_extend('force', ..., { t = 'status', buf = buf, started = now, changed = now })
    pipe:write(proto.encode({ t = 'hello', role = 'nvim', pid = vim.fn.getpid(), server = vim.v.servername }))
    pipe:write(proto.encode(msg))
    return buf
  ]],
    { status }
  )
end

T['the agents buffer lists every agent and jumps to one'] = function()
  start_hub()
  children[1].setup()
  children[2].setup()
  local alpha = fake_agent(children[1], { state = 'working', workspace = 'alpha', title = 'Fix the parser' })
  fake_agent(children[2], { state = 'blocked', kind = 'permission', workspace = 'beta' })
  eq(#wait_list(2), 2)

  local child = children[1]
  child.lua([[require('huey.hub.agents').open()]])
  local lines
  vim.wait(5000, function()
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    return #lines == 3
  end, 50)
  eq(#lines, 3)
  expect.match(lines[1], '^%s+STATE')
  expect.match(lines[2], 'working.*alpha.*Fix the parser')
  expect.match(lines[3], 'blocked%(permission%).*beta')

  -- alpha lives in this nvim, so Enter shows its buffer here and closes the list
  child.api.nvim_win_set_cursor(0, { 2, 0 })
  child.type_keys('<CR>')
  eq(child.api.nvim_get_current_buf(), alpha)
  eq(#child.api.nvim_list_wins(), 1)
  eq(child.fn.bufexists('huey://agents'), 0)
end

T['the agents buffer follows the hub'] = function()
  start_hub()
  children[1].setup()
  local child = children[1]
  child.lua([[require('huey.hub.agents').open()]])
  local lines = function() return child.api.nvim_buf_get_lines(0, 0, -1, false) end
  vim.wait(2000, function() return lines()[2] == '   no agents' end, 50)
  eq(lines()[2], '   no agents')

  fake_agent(child, { state = 'done', workspace = 'alpha' })
  vim.wait(5000, function() return #lines() == 2 and lines()[2]:find('alpha') ~= nil end, 50)
  expect.match(lines()[2], 'done.*alpha')

  -- closing the list wipes it and drops its hub connection
  child.type_keys('q')
  eq(child.fn.bufexists('huey://agents'), 0)
end

T['an nvim starts the hub when none is running'] = function()
  start_agent(children[1], 'alpha', 'state=done')
  local agents = wait_list(1)
  eq(#agents, 1)
  eq(agents[1].state, 'done')
end

T['a second hub on the same socket exits'] = function()
  start_hub()
  local second = vim.fn.jobstart({ vim.v.progpath, '-l', huey, 'serve' })
  eq(vim.fn.jobwait({ second }, 5000)[1], 0)
  -- the first still answers
  eq(list(), {})
end

T['the hub exits once nothing is connected'] = function()
  start_hub()
  -- idle is 500ms in tests
  eq(vim.fn.jobwait({ hub_job }, 5000)[1], 0)
  hub_job = nil
end

return T
