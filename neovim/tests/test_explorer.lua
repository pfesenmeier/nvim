local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local project_names = { 'alpha', 'beta', 'gamma' }

local temp_roots = {}
-- jj repos from `helpers.new_jj_repo()`, deleted after each case
local repos = {}

--- Loads the explorer in the child over a store listing `project_names`, with
--- `status` stubbed (no sockets probed) and `connect` recording its target.
--- @param running table<string, boolean> which projects report 'running'
--- @param cwd string? project to chdir into first
--- @param paths table<string, string>? project name -> path, for projects that
---   must be somewhere other than a fresh empty folder
--- @return string root holding the store and the workspace dir
local setup = function(running, cwd, paths)
  local root = vim.fn.tempname()
  table.insert(temp_roots, root)
  local spec = {}
  for _, name in ipairs(project_names) do
    local path = (paths or {})[name] or (root .. '/' .. name)
    vim.fn.mkdir(path, 'p')
    spec[#spec + 1] = { name = name, path = path }
  end
  vim.fn.writefile({ vim.json.encode(spec) }, root .. '/projects.json')

  child.lua(
    [[
    local o, running = ...
    local projects = require('huey.projects')
    projects.setup(o)
    projects.status = function(name) return running[name] and 'running' or 'stopped' end
    _G.connected = {}
    projects.connect = function(name) table.insert(_G.connected, name) end
    _G.explorer = require('huey.explorer')
  ]],
    {
      {
        store = root .. '/projects.json',
        pinned = {},
        server_dir = root .. '/servers',
        workspace_dir = root .. '/workspaces',
      },
      running or {},
    }
  )
  if cwd then child.fn.chdir((paths or {})[cwd] or (root .. '/' .. cwd)) end
  return root
end

local open = function() child.lua('_G.explorer.open()') end
local is_float = function() return child.api.nvim_win_get_config(0).relative ~= '' end
local cursor_line = function() return child.api.nvim_win_get_cursor(0)[1] end

--- Presses `keys`, then lets `vim.schedule` callbacks run.
local press = function(keys)
  child.type_keys(keys)
  child.poke_eventloop()
end

local T = new_set({
  hooks = {
    pre_case = child.setup,
    post_case = function()
      for _, root in ipairs(temp_roots) do
        vim.fn.delete(root, 'rf')
      end
      for _, repo in ipairs(repos) do
        vim.fn.delete(repo, 'rf')
      end
      temp_roots, repos = {}, {}
    end,
    post_once = child.stop,
  },
})

T['open()'] = new_set()

T['open()']['lists projects in a focused float'] = function()
  setup({})
  open()
  eq(is_float(), true)
  eq(child.get_lines(), project_names)
  eq(child.bo.modifiable, false)
end

T['open()']['starts on the current project'] = function()
  setup({}, 'gamma')
  open()
  eq(cursor_line(), 3)
end

T['open()']['starts on the first project outside any project'] = function()
  setup({})
  open()
  eq(cursor_line(), 1)
end

T['open()']['marks running projects'] = function()
  setup({ beta = true })
  open()
  local glyphs = child.lua_get([[vim.tbl_map(function(m)
    return m[4].virt_text[1][1]
  end, vim.tbl_filter(function(m)
    return m[4].virt_text_pos == 'inline'
  end, vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })))]])
  eq(glyphs, { '○ ', '● ', '○ ' })
end

T['open()']['focuses the pane when already open'] = function()
  setup({})
  open()
  local win = child.api.nvim_get_current_win()
  open()
  eq(#child.api.nvim_list_wins(), 2)
  eq(child.api.nvim_get_current_win(), win)
end

T['keys'] = new_set()

T['keys']['<CR> connects to the project under the cursor'] = function()
  setup({})
  open()
  press('j<CR>')
  eq(child.lua_get('_G.connected'), { 'beta' })
  eq(is_float(), false)
end

T['keys']['l on a project that is not a jj repo stays put'] = function()
  setup({})
  open()
  local win = child.api.nvim_get_current_win()
  press('l')
  eq(child.api.nvim_get_current_win(), win)
  eq(#child.api.nvim_list_wins(), 2)
  eq(child.lua_get('_G.connected'), {})
end

T['keys']['<CR> on the current project only closes'] = function()
  setup({}, 'beta')
  open()
  press('<CR>')
  eq(child.lua_get('_G.connected'), {})
  eq(is_float(), false)
end

T['keys']['q and <Esc> close'] = function()
  setup({})
  open()
  press('q')
  eq(is_float(), false)
  open()
  press('<Esc>')
  eq(is_float(), false)
  eq(child.lua_get('_G.connected'), {})
end

T['keys']['leaving the pane closes it'] = function()
  setup({})
  open()
  child.cmd('wincmd p')
  child.poke_eventloop()
  eq(#child.api.nvim_list_wins(), 1)
end

T['workspaces'] = new_set()

--- Like `setup()`, with project `beta` at a fresh jj repo. Confirm prompts
--- answer `answer` (1 is yes) and record their message in `_G.prompts`;
--- notifications are recorded in `_G.notes` rather than shown.
--- @param answer integer?
--- @return string root, string repo
local setup_jj = function(answer)
  helpers.skip_if_no_jj()
  local repo = helpers.new_jj_repo({ ['a.txt'] = { 'a' } })
  table.insert(repos, repo)
  local root = setup({}, nil, { beta = repo })
  child.lua(
    [[
    local answer = ...
    _G.prompts, _G.notes = {}, {}
    vim.notify = function(msg) table.insert(_G.notes, msg) end
    vim.fn.confirm = function(msg)
      table.insert(_G.prompts, msg)
      return answer
    end
  ]],
    { answer or 1 }
  )
  return root, repo
end

--- Opens the workspace pane of `beta`.
local open_beta = function()
  open()
  press('jl')
end

--- Workspace names jj itself knows about in `repo`.
local jj_workspaces = function(repo)
  local out = helpers.jj(repo, 'workspace', 'list', '-T', 'name ++ "\\n"')
  return vim.split(vim.trim(out), '\n')
end

T['workspaces']['l opens the default workspace right of the projects'] = function()
  setup_jj()
  open()
  local left = child.api.nvim_win_get_config(0)
  press('jl')
  eq(is_float(), true)
  eq(#child.api.nvim_list_wins(), 3)
  eq(child.get_lines(), { 'default' })
  eq(child.bo.modifiable, true)
  eq(child.api.nvim_win_get_config(0).col, left.col + left.width + 2)
end

T['workspaces']['= creates a workspace for a new line'] = function()
  local root, repo = setup_jj()
  open_beta()
  press('ofeature<Esc>=')
  eq(jj_workspaces(repo), { 'default', 'feature' })
  local path = root .. '/workspaces/beta/feature'
  eq(vim.fn.filereadable(path .. '/a.txt'), 1)
  eq(child.get_lines(), { 'default', 'feature' })
  eq(child.lua_get('_G.prompts[1]'):find('CREATE │ feature', 1, true) ~= nil, true)
end

T['workspaces']['= creates nothing when declined'] = function()
  local _, repo = setup_jj(2)
  open_beta()
  press('ofeature<Esc>=')
  eq(jj_workspaces(repo), { 'default' })
  -- the edit stays, to fix or confirm again
  eq(child.get_lines(), { 'default', 'feature' })
end

T['workspaces']['= keeps a deleted workspace'] = function()
  local _, repo = setup_jj()
  open_beta()
  press('dd=')
  eq(jj_workspaces(repo), { 'default' })
  eq(child.get_lines(), { 'default' })
  eq(child.lua_get('#_G.prompts'), 0)
  eq(
    child.lua_get('_G.notes'),
    { 'explorer: removing workspaces is not supported; kept default' }
  )
end

T['workspaces']['= rejects a name that is not a folder name'] = function()
  local _, repo = setup_jj()
  open_beta()
  press('oa/b<Esc>=')
  eq(jj_workspaces(repo), { 'default' })
  eq(child.get_lines(), { 'default' })
  eq(child.lua_get('_G.notes'), { "projects: 'a/b' is not a valid workspace name" })
end

T['workspaces']['lists other workspaces after the default one'] = function()
  local root, repo = setup_jj()
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/aaa')
  open_beta()
  eq(child.get_lines(), { 'default', 'aaa' })
end

--- Records `projects.cd()` calls in `_G.cds` rather than changing directory.
local stub_cd = function()
  child.lua([[
    _G.cds = {}
    require('huey.projects').cd = function(name, path)
      table.insert(_G.cds, { name, vim.fn.resolve(path) })
    end
  ]])
end

T['workspaces']['<CR> changes directory to the workspace under the cursor'] = function()
  local root, repo = setup_jj()
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/aaa')
  child.fn.chdir(repo)
  open()
  press('l')
  press('j<CR>')
  eq(vim.fn.resolve(child.fn.getcwd()), vim.fn.resolve(root .. '/aaa'))
  eq(#child.api.nvim_list_wins(), 1)
  eq(child.lua_get('_G.connected'), {})
end

T['workspaces']['<CR> hands a workspace of another project to projects.cd()'] = function()
  local _, repo = setup_jj()
  stub_cd()
  open_beta()
  press('<CR>')
  eq(child.lua_get('_G.cds'), { { 'beta', vim.fn.resolve(repo) } })
  eq(#child.api.nvim_list_wins(), 1)
end

T['workspaces']['<CR> on an unsynced line does nothing'] = function()
  setup_jj()
  stub_cd()
  open_beta()
  press('ofeature<Esc><CR>')
  eq(child.lua_get('_G.cds'), {})
  eq(#child.api.nvim_list_wins(), 3)
end

T['workspaces']['h goes back to the projects'] = function()
  setup_jj()
  open_beta()
  press('h')
  eq(#child.api.nvim_list_wins(), 2)
  eq(child.api.nvim_buf_get_name(0), 'huey://projects')
  eq(cursor_line(), 2)
end

T['workspaces']['leaving for another window closes both panes'] = function()
  setup_jj()
  open_beta()
  child.cmd('wincmd t')
  child.poke_eventloop()
  eq(#child.api.nvim_list_wins(), 1)
end

return T
