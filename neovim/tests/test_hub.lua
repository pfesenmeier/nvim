local helpers = dofile('tests/helpers.lua')

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
