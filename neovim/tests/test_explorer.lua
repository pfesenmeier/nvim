local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local project_names = { 'alpha', 'beta', 'gamma' }

local temp_roots = {}
-- jj repos from `helpers.new_jj_repo()`, deleted after each case
local repos = {}

--- Loads the explorer in the child over a store listing `project_names`, with
--- `status` stubbed (no sockets probed) and `connect` recording its target as
--- a label, e.g. 'beta/feature'.
--- @param running table<string, boolean> which labels report 'running'; a
---   project reports running when any of its workspaces does
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
    projects.status = function(name, ws)
      if running[projects.label(name, ws)] then return 'running' end
      if not ws then
        for label in pairs(running) do
          if vim.startswith(label, name .. '/') then return 'running' end
        end
      end
      return 'stopped'
    end
    _G.connected = {}
    projects.connect = function(name, ws)
      table.insert(_G.connected, projects.label(name, ws))
    end
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
  eq(child.bo.modifiable, true)
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

--- Running glyph on each line of the current pane.
local glyphs = function()
  return child.lua_get([[vim.tbl_map(function(m)
    return m[4].virt_text[1][1]
  end, vim.tbl_filter(function(m)
    return m[4].virt_text_pos == 'inline'
  end, vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })))]])
end

T['open()']['marks running projects'] = function()
  setup({ beta = true })
  open()
  eq(glyphs(), { '○ ', '● ', '○ ' })
end

T['open()']['marks a project running when only a workspace server is'] = function()
  setup({ ['gamma/feature'] = true })
  open()
  eq(glyphs(), { '○ ', '○ ', '● ' })
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

T['projects'] = new_set()

--- Like `setup()`, with confirm prompts answering `answer` (1 is yes) and
--- recording their message in `_G.prompts`, and notifications recorded in
--- `_G.notes`.
--- @param answer integer?
--- @return string root
local setup_prompts = function(answer)
  local root = setup({})
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
  return root
end

--- Project names in the store at `root`.
local stored_names = function(root)
  local list = vim.json.decode(table.concat(vim.fn.readfile(root .. '/projects.json'), '\n'))
  return vim.tbl_map(function(p) return p.name end, list)
end

T['projects']['= removes a project from the list, not from disk'] = function()
  local root = setup_prompts()
  open()
  press('jdd=')
  eq(stored_names(root), { 'alpha', 'gamma' })
  eq(child.get_lines(), { 'alpha', 'gamma' })
  eq(vim.fn.isdirectory(root .. '/beta'), 1)
  eq(child.lua_get('_G.prompts[1]'):find('DELETE │ beta', 1, true) ~= nil, true)
end

T['projects']['= keeps the current project'] = function()
  local root = setup_prompts()
  child.fn.chdir(root .. '/beta')
  open()
  press('dd=')
  eq(stored_names(root), project_names)
  eq(child.lua_get('#_G.prompts'), 0)
  eq(child.lua_get('_G.notes'), { "explorer: can't remove the current project; kept beta" })
end

T['projects']['= removes nothing when declined'] = function()
  local root = setup_prompts(2)
  open()
  press('jdd=')
  eq(stored_names(root), project_names)
  -- the edit stays, to fix or confirm again
  eq(child.get_lines(), { 'alpha', 'gamma' })
end

T['projects']['= ignores a new line'] = function()
  local root = setup_prompts()
  open()
  press('onew<Esc>=')
  eq(stored_names(root), project_names)
  eq(child.lua_get('#_G.prompts'), 0)
  eq(child.get_lines(), project_names)
  eq(
    child.lua_get('_G.notes'),
    { 'explorer: adding projects is not supported, use :ProjectAdd; ignored new' }
  )
end

T['projects']['<CR> on an edited line does nothing'] = function()
  setup({})
  open()
  press('ccbet<Esc><CR>')
  eq(child.lua_get('_G.connected'), {})
  eq(is_float(), true)
end

T['workspaces'] = new_set()

--- Like `setup()`, with project `beta` at a fresh jj repo. Confirm prompts
--- answer `answer` (1 is yes) and record their message in `_G.prompts`;
--- notifications are recorded in `_G.notes` rather than shown.
--- @param answer integer?
--- @param running table<string, boolean>? as for `setup()`
--- @return string root, string repo
local setup_jj = function(answer, running)
  helpers.skip_if_no_jj()
  local repo = helpers.new_jj_repo({ ['a.txt'] = { 'a' } })
  table.insert(repos, repo)
  local root = setup(running or {}, nil, { beta = repo })
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

--- Workspace names jj itself knows about in `repo`, sorted.
local jj_workspaces = function(repo)
  local out = helpers.jj(repo, 'workspace', 'list', '-T', 'name ++ "\\n"')
  local names = vim.split(vim.trim(out), '\n')
  table.sort(names)
  return names
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

T['workspaces']['= keeps the default workspace'] = function()
  local _, repo = setup_jj()
  open_beta()
  press('dd=')
  eq(jj_workspaces(repo), { 'default' })
  eq(child.get_lines(), { 'default' })
  eq(child.lua_get('#_G.prompts'), 0)
  eq(
    child.lua_get('_G.notes'),
    { "explorer: can't remove the default or current workspace; kept default" }
  )
end

T['workspaces']['= keeps the current workspace'] = function()
  local root, repo = setup_jj()
  vim.fn.mkdir(root .. '/workspaces/beta', 'p')
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/workspaces/beta/aaa')
  child.fn.chdir(root .. '/workspaces/beta/aaa')
  -- opens on beta, the current project
  open()
  press('ljdd=')
  eq(jj_workspaces(repo), { 'aaa', 'default' })
  eq(child.lua_get('#_G.prompts'), 0)
end

T['workspaces']['= deletes a workspace whose line was deleted'] = function()
  local root, repo = setup_jj()
  local path = root .. '/aaa'
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', path)
  open_beta()
  press('jdd=')
  eq(jj_workspaces(repo), { 'default' })
  eq(vim.fn.isdirectory(path), 0)
  eq(child.get_lines(), { 'default' })
  eq(child.lua_get('_G.prompts[1]'):find('DELETE │ aaa', 1, true) ~= nil, true)
end

T['workspaces']['= deletes nothing when declined'] = function()
  local root, repo = setup_jj(2)
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/aaa')
  open_beta()
  press('jdd=')
  eq(jj_workspaces(repo), { 'aaa', 'default' })
  eq(vim.fn.isdirectory(root .. '/aaa'), 1)
end

T['workspaces']['= creates and deletes in one go'] = function()
  local root, repo = setup_jj()
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/aaa')
  open_beta()
  press('jccfeature<Esc>=')
  eq(jj_workspaces(repo), { 'default', 'feature' })
  local prompt = child.lua_get('_G.prompts[1]')
  eq(prompt:find('DELETE │ aaa\n  CREATE │ feature', 1, true) ~= nil, true)
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

T['workspaces']['marks running workspace servers'] = function()
  local root, repo = setup_jj(1, { ['beta/aaa'] = true })
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/aaa')
  open_beta()
  eq(glyphs(), { '○ ', '● ' })
end

T['workspaces']['<CR> connects to the server of the workspace under the cursor'] = function()
  local root, repo = setup_jj()
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/aaa')
  open_beta()
  press('j<CR>')
  eq(child.lua_get('_G.connected'), { 'beta/aaa' })
  eq(#child.api.nvim_list_wins(), 1)
end

T['workspaces']['<CR> on the default workspace connects to the project'] = function()
  setup_jj()
  open_beta()
  press('<CR>')
  eq(child.lua_get('_G.connected'), { 'beta' })
  eq(#child.api.nvim_list_wins(), 1)
end

T['workspaces']['<CR> on the current workspace only closes'] = function()
  local _, repo = setup_jj()
  child.fn.chdir(repo)
  open()
  press('l<CR>')
  eq(child.lua_get('_G.connected'), {})
  eq(#child.api.nvim_list_wins(), 1)
end

T['workspaces']['<CR> on an unsynced line does nothing'] = function()
  setup_jj()
  open_beta()
  press('ofeature<Esc><CR>')
  eq(child.lua_get('_G.connected'), {})
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

T['agents'] = new_set()

local columns

--- Like `setup_jj()`, with the agent functions of 'huey.projects' stubbed over
--- `_G.agents`, a list of agents per server label. `all_agents` goes through
--- the labels in sorted order. `add_agent` appends one that shows its prompt
--- and records `{ label, prompt }` in `_G.added`; `open_agent` records
--- `{ label, bufnr }` in `_G.opened`; `remove_agent` drops one and records
--- `{ label, bufnr }` in `_G.removed`; an agent's output is
--- `{ 'output of <bufnr>' }`.
--- @param agents table<string, table[]>? initial agents per label
--- @param answer integer? confirm answer, 1 is yes
local setup_agents = function(agents, answer)
  local root, repo = setup_jj(answer)
  -- room for the preview past the long temp paths in the other panes
  child.o.columns = 400
  child.lua(
    [[
    local projects = require('huey.projects')
    _G.agents, _G.added, _G.opened, _G.removed = ..., {}, {}, {}
    local rows = function(label)
      local name, ws = label:match('^([^/]+)/(.+)$')
      return vim.tbl_map(function(g)
        return vim.tbl_extend('force', g, { project = name or label, workspace = ws or 'default' })
      end, _G.agents[label] or {})
    end
    projects.agents = function(name, ws) return rows(projects.label(name, ws)) end
    projects.all_agents = function(name)
      local labels = vim.tbl_keys(_G.agents)
      table.sort(labels)
      local out = {}
      for _, label in ipairs(labels) do
        if not name or label == name or vim.startswith(label, name .. '/') then
          vim.list_extend(out, rows(label))
        end
      end
      return out
    end
    projects.add_agent = function(name, ws, prompt)
      local label = projects.label(name, ws)
      _G.agents[label] = _G.agents[label] or {}
      local buf = 100 + #_G.added
      table.insert(_G.agents[label], { bufnr = buf, icon = '·', text = prompt, prompt = prompt })
      table.insert(_G.added, { label, prompt })
      return buf
    end
    projects.remove_agent = function(name, ws, bufnr)
      local label = projects.label(name, ws)
      _G.agents[label] = vim.tbl_filter(function(g) return g.bufnr ~= bufnr end, _G.agents[label])
      table.insert(_G.removed, { label, bufnr })
      return true
    end
    projects.agent_lines = function(_, _, bufnr) return { 'output of ' .. bufnr } end
    projects.open_agent = function(name, ws, bufnr)
      table.insert(_G.opened, { projects.label(name, ws), bufnr })
    end
  ]],
    { agents or {} }
  )
  return root, repo
end

local working = { bufnr = 7, icon = '∿', text = 'Fixing the bug', prompt = 'fix the bug' }
local idle = { bufnr = 9, icon = '·', text = 'review the diff', prompt = 'review the diff' }

--- Opens the agent pane of beta's default workspace.
local open_beta_agents = function()
  open_beta()
  press('l')
end

--- Lines of the preview float.
local preview_lines = function()
  return child.lua_get([[(function()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if not vim.api.nvim_win_get_config(w).focusable then
        return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false)
      end
    end
  end)()]])
end

--- Text of every end-of-line detail in the current pane, in line order.
local details = function()
  return child.lua_get([[vim.tbl_map(function(m)
    return { m[2], m[4].virt_text[1][1] }
  end, vim.tbl_filter(function(m)
    return m[4].virt_text_pos == 'eol'
  end, vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })))]])
end

T['agents']['l opens the agents of the workspace right of it'] = function()
  setup_agents({ beta = { working, idle } })
  open_beta()
  local left = child.api.nvim_win_get_config(0)
  press('l')
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/beta')
  eq(child.get_lines(), { 'Fixing the bug', 'review the diff' })
  eq(glyphs(), { '∿ ', '· ' })
  eq(child.api.nvim_win_get_config(0).col, left.col + left.width + 2)
  -- projects, workspaces, agents, preview
  eq(#child.api.nvim_list_wins(), 5)
end

--- Chunks of the columns ahead of line `lnum` (0-based) of the current pane.
columns = function(lnum)
  return child.lua_get(
    [[vim.tbl_filter(function(m)
      return m[4].virt_text_pos == 'inline'
    end, vim.api.nvim_buf_get_extmarks(0, -1, { ..., 0 }, { ..., -1 }, { details = true }))[1][4].virt_text]],
    { lnum }
  )
end

T['agents']['shows the state of each agent and how long it has been in it'] = function()
  local now = os.time()
  setup_agents({
    beta = {
      vim.tbl_extend('force', working, {
        icon = '◑',
        state = 'working',
        progress = 40,
        changed = now - 90,
        started = now - 7200,
      }),
      vim.tbl_extend('force', idle, {
        icon = '⏸',
        state = 'blocked',
        kind = 'permission',
        msg = 'run\nrm?',
        changed = now,
        started = now,
      }),
      { bufnr = 12, icon = '·', text = 'just started', prompt = 'just started' },
    },
  })
  open_beta_agents()
  eq(columns(0), {
    { '◑ ', 'DiagnosticInfo' },
    { 'working 40%         ', 'DiagnosticInfo' },
    { ' 1m  2h  ', 'Comment' },
  })
  eq(columns(1)[2], { 'blocked(permission) ', 'DiagnosticWarn' })
  eq(columns(2), {
    { '· ', 'Comment' },
    { '                    ', 'Comment' },
    { '         ', 'Comment' },
  })
  -- why it is blocked comes after the line
  eq(details(), { { 0, '  fix the bug' }, { 1, '  run rm?' } })
end

T['agents']['keeps up with the agents while open'] = function()
  setup_agents({ beta = { working, idle } })
  open_beta_agents()
  press('j')
  child.lua([[
    table.insert(_G.agents.beta, 1, { bufnr = 20, icon = '∿', text = 'new one' })
    _G.agents.beta[3].icon = '●'
  ]])
  eq(child.wait_for([[vim.api.nvim_buf_line_count(0) == 3]]), true)
  eq(child.get_lines(), { 'new one', 'Fixing the bug', 'review the diff' })
  eq(glyphs(), { '∿ ', '∿ ', '● ' })
  -- still on the agent it was on
  eq(cursor_line(), 3)
  -- a re-list is not an edit to undo
  press('u')
  eq(child.get_lines(), { 'new one', 'Fixing the bug', 'review the diff' })
end

T['agents']['leaves unsynced edits alone'] = function()
  setup_agents({ beta = { working } })
  open_beta_agents()
  press('oadd tests<Esc>')
  child.lua([[_G.agents.beta[1].text = 'Changed']])
  vim.uv.sleep(1500)
  child.poke_eventloop()
  eq(child.get_lines(), { 'Fixing the bug', 'add tests' })
end

T['agents']['shows the prompt after a line once the title differs'] = function()
  setup_agents({ beta = { working, idle } })
  open_beta_agents()
  eq(details(), { { 0, '  fix the bug' } })
end

T['agents']['previews the output of the agent under the cursor'] = function()
  setup_agents({ beta = { working, idle } })
  open_beta_agents()
  eq(preview_lines(), { 'output of 7' })
  press('j')
  eq(preview_lines(), { 'output of 9' })
end

T['agents']['leaves out the preview when there is no room'] = function()
  setup_agents({ beta = { working } })
  child.o.columns = 80
  open_beta_agents()
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/beta')
  eq(preview_lines(), vim.NIL)
  -- comes back on the next resize once the screen has room
  child.o.columns = 400
  press('ix<Esc>u')
  eq(preview_lines(), { 'output of 7' })
end

T['agents']['an empty pane is ready for a prompt'] = function()
  setup_agents()
  open_beta_agents()
  eq(child.get_lines(), { '' })
  eq(child.bo.modifiable, true)
  eq(preview_lines(), { '' })
end

T['agents']['= starts an agent for a new line'] = function()
  setup_agents({ beta = { working } })
  open_beta_agents()
  press('oadd tests<Esc>=')
  eq(child.lua_get('_G.added'), { { 'beta', 'add tests' } })
  eq(child.get_lines(), { 'Fixing the bug', 'add tests' })
  eq(
    child.lua_get('_G.prompts[1]'):find('Synchronize agents of beta?', 1, true) ~= nil,
    true
  )
  eq(child.lua_get('_G.prompts[1]'):find('CREATE │ add tests', 1, true) ~= nil, true)
end

T['agents']['= starts an agent in a workspace that is not default'] = function()
  local root, repo = setup_agents()
  helpers.jj(repo, 'workspace', 'add', '--name', 'aaa', root .. '/aaa')
  open_beta()
  press('jl')
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/beta/aaa')
  press('ifix it<Esc>=')
  eq(child.lua_get('_G.added'), { { 'beta/aaa', 'fix it' } })
end

T['agents']['= starts nothing when declined'] = function()
  setup_agents({}, 2)
  open_beta_agents()
  press('ifix it<Esc>=')
  eq(child.lua_get('_G.added'), {})
  -- the edit stays, to fix or confirm again
  eq(child.get_lines(), { 'fix it' })
end

T['agents']['= stops an agent whose line was deleted'] = function()
  setup_agents({ beta = { working, idle } })
  open_beta_agents()
  press('dd=')
  eq(child.lua_get('_G.removed'), { { 'beta', 7 } })
  eq(child.get_lines(), { 'review the diff' })
  eq(child.lua_get('_G.prompts[1]'):find('DELETE │ Fixing the bug', 1, true) ~= nil, true)
end

T['agents']['= stops nothing when declined'] = function()
  setup_agents({ beta = { working } }, 2)
  open_beta_agents()
  press('dd=')
  eq(child.lua_get('_G.removed'), {})
  eq(child.get_lines(), { '' })
end

T['agents']['= stops the later of two agents with the same line'] = function()
  local twin = vim.tbl_extend('force', idle, { bufnr = 11 })
  setup_agents({ beta = { idle, twin } })
  open_beta_agents()
  press('dd=')
  eq(child.lua_get('_G.removed'), { { 'beta', 11 } })
  eq(child.get_lines(), { 'review the diff' })
end

T['agents']['<CR> opens the agent under the cursor'] = function()
  setup_agents({ beta = { working, idle } })
  open_beta_agents()
  press('j<CR>')
  eq(child.lua_get('_G.opened'), { { 'beta', 9 } })
  eq(#child.api.nvim_list_wins(), 1)
end

T['agents']['<CR> on an unsynced line does nothing'] = function()
  setup_agents({ beta = { working } })
  open_beta_agents()
  press('ofix it<Esc><CR>')
  eq(child.lua_get('_G.opened'), {})
  eq(#child.api.nvim_list_wins(), 5)
end

T['agents']['l on an unsynced workspace does nothing'] = function()
  setup_agents()
  open_beta()
  press('ofeature<Esc>l')
  eq(child.api.nvim_buf_get_name(0), 'huey://workspaces/beta')
  eq(#child.api.nvim_list_wins(), 3)
end

T['agents']['h goes back to the workspaces'] = function()
  setup_agents({ beta = { working } })
  open_beta_agents()
  press('h')
  eq(child.api.nvim_buf_get_name(0), 'huey://workspaces/beta')
  eq(#child.api.nvim_list_wins(), 3)
end

T['agents']['leaving for another window closes every pane'] = function()
  setup_agents({ beta = { working } })
  open_beta_agents()
  child.cmd('wincmd t')
  child.poke_eventloop()
  eq(#child.api.nvim_list_wins(), 1)
end

T['agents']['q closes every pane'] = function()
  setup_agents({ beta = { working } })
  open_beta_agents()
  press('q')
  eq(#child.api.nvim_list_wins(), 1)
end

T['tab'] = new_set()

local other = { bufnr = 3, icon = '⏸', text = 'needs input', prompt = 'needs input' }
local elsewhere = { bufnr = 4, icon = '∿', text = 'in alpha' }

T['tab']['in the projects pane lists the agents of every project'] = function()
  setup_agents({ alpha = { elsewhere }, beta = { working }, ['beta/aaa'] = { other } })
  open()
  local left = child.api.nvim_win_get_config(0)
  press('<Tab>')
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/*')
  eq(child.get_lines(), { 'in alpha', 'Fixing the bug', 'needs input' })
  eq(glyphs(), { '∿ ', '∿ ', '⏸ ' })
  eq(child.api.nvim_win_get_config(0).col, left.col + left.width + 2)
  -- projects, agents, preview
  eq(#child.api.nvim_list_wins(), 4)
end

T['tab']['labels each agent with its workspace'] = function()
  setup_agents({ beta = { working }, ['beta/aaa'] = { other } })
  open()
  press('<Tab>')
  eq(columns(0), { { '∿ ', 'Comment' }, { 'beta      ', 'Directory' } })
  eq(columns(1), { { '⏸ ', 'Comment' }, { 'beta/aaa  ', 'Directory' } })
  eq(details(), { { 0, '  fix the bug' } })
end

T['tab']['in the projects pane closes the agents when they are open'] = function()
  setup_agents({ beta = { working } })
  open()
  local projects_win = child.api.nvim_get_current_win()
  press('<Tab>')
  child.api.nvim_set_current_win(projects_win)
  child.poke_eventloop()
  press('<Tab>')
  eq(child.api.nvim_get_current_win(), projects_win)
  eq(#child.api.nvim_list_wins(), 2)
end

T['tab']['in the workspace pane lists the agents of the project'] = function()
  setup_agents({ alpha = { elsewhere }, beta = { working }, ['beta/aaa'] = { other } })
  open_beta()
  press('<Tab>')
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/beta/*')
  eq(child.get_lines(), { 'Fixing the bug', 'needs input' })
  -- projects, workspaces, agents, preview
  eq(#child.api.nvim_list_wins(), 5)
end

T['tab']['in the workspace pane replaces the agents of a workspace'] = function()
  setup_agents({ beta = { working }, ['beta/aaa'] = { other } })
  open_beta()
  local ws_win = child.api.nvim_get_current_win()
  press('l')
  eq(child.get_lines(), { 'Fixing the bug' })
  child.api.nvim_set_current_win(ws_win)
  child.poke_eventloop()
  press('<Tab>')
  eq(child.get_lines(), { 'Fixing the bug', 'needs input' })
  eq(#child.api.nvim_list_wins(), 5)
end

T['tab']['in an agent pane does nothing'] = function()
  setup_agents({ beta = { working } })
  open()
  press('<Tab>')
  local win = child.api.nvim_get_current_win()
  press('<Tab>')
  eq(child.api.nvim_get_current_win(), win)
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/*')
  eq(#child.api.nvim_list_wins(), 4)
end

T['tab']['<CR> opens the agent in its own workspace'] = function()
  setup_agents({ beta = { working }, ['beta/aaa'] = { other } })
  open()
  press('<Tab>j<CR>')
  eq(child.lua_get('_G.opened'), { { 'beta/aaa', 3 } })
  eq(#child.api.nvim_list_wins(), 1)
end

T['tab']['previews the agent in its own workspace'] = function()
  setup_agents({ beta = { working }, ['beta/aaa'] = { other } })
  child.lua([[require('huey.projects').agent_lines = function(name, ws, bufnr)
    return { name .. '/' .. ws .. ' ' .. bufnr }
  end]])
  open()
  press('<Tab>j')
  eq(preview_lines(), { 'beta/aaa 3' })
end

T['tab']['says so when no agent is running'] = function()
  setup_agents()
  open()
  press('<Tab>')
  eq(child.get_lines(), { '' })
  eq(details(), { { 0, 'no agents running' } })
end

T['tab']['= stops an agent in its own workspace'] = function()
  setup_agents({ beta = { working }, ['beta/aaa'] = { other } })
  open()
  press('<Tab>jdd=')
  eq(child.lua_get('_G.removed'), { { 'beta/aaa', 3 } })
  eq(child.get_lines(), { 'Fixing the bug' })
  eq(
    child.lua_get('_G.prompts[1]'):find('DELETE │ needs input  (beta/aaa)', 1, true) ~= nil,
    true
  )
end

T['tab']['= starts no agent for a new line'] = function()
  setup_agents({ beta = { working } })
  open()
  press('<Tab>ofix it<Esc>=')
  eq(child.lua_get('_G.added'), {})
  eq(child.lua_get('#_G.prompts'), 0)
  eq(child.get_lines(), { 'Fixing the bug' })
  eq(
    child.lua_get('_G.notes'),
    { 'explorer: agents start in one workspace, open its agents with l; ignored fix it' }
  )
end

T['tab']['h goes back to the pane it opened from'] = function()
  setup_agents({ beta = { working } })
  open_beta()
  press('<Tab>h')
  eq(child.api.nvim_buf_get_name(0), 'huey://workspaces/beta')
  eq(#child.api.nvim_list_wins(), 3)
end

T['open_agents()'] = new_set()

T['open_agents()']['opens the agents of the current project'] = function()
  local _, repo = setup_agents({ alpha = { elsewhere }, beta = { working }, ['beta/aaa'] = { other } })
  child.fn.chdir(repo)
  child.lua('_G.explorer.open_agents()')
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/beta/*')
  eq(child.get_lines(), { 'Fixing the bug', 'needs input' })
  -- projects, workspaces, agents, preview
  eq(#child.api.nvim_list_wins(), 5)
  press('h')
  eq(child.api.nvim_buf_get_name(0), 'huey://workspaces/beta')
end

T['open_agents()']['opens the agents of every project outside one'] = function()
  setup_agents({ alpha = { elsewhere }, beta = { working } })
  child.lua('_G.explorer.open_agents()')
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/*')
  eq(child.get_lines(), { 'in alpha', 'Fixing the bug' })
  -- projects, agents, preview
  eq(#child.api.nvim_list_wins(), 4)
end

T['open_agents()']['reopens an open explorer'] = function()
  setup_agents({ beta = { working } })
  open_beta()
  child.lua('_G.explorer.open_agents()')
  eq(child.api.nvim_buf_get_name(0), 'huey://agents/*')
  eq(#child.api.nvim_list_wins(), 4)
end

return T
