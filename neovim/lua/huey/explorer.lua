-- Huey explorer: floating panes for moving between projects, a la 'mini.files'.
-- The left pane lists projects: `<CR>` connects the UI to the default
-- workspace of the one under the cursor and `l` opens its jj workspaces in a
-- pane to the right. Every workspace has its own server, and there `<CR>`
-- connects the UI to the one under the cursor. That pane is editable: add a
-- line and press `=` to create a workspace by that name. `l` there opens the
-- agent terminals of that workspace's server, where a new line and `=` start
-- an agent with that line as its prompt. In every pane, deleting a line and
-- pressing `=` removes what it names: a project leaves the list and its
-- servers stop, a workspace
-- is forgotten by jj and deleted from disk along with its server, and an
-- agent's terminal is deleted. `<Tab>` opens the agents of every
-- project from the project pane, or of every workspace of the project from the
-- workspace pane; press it there again to close them. See 'lua/huey/projects'.
local projects = require('huey.projects')

local Explorer = {}
local H = {}

H.ns = vim.api.nvim_create_namespace('HueyExplorer')

--- Project pane; `names` is the project name on each line as last read from
--- the store
H.projects = { win = nil, buf = nil, names = {} }

--- Workspace pane for `project`; `names` is the workspace on each line as last
--- read from jj
H.workspaces = { win = nil, buf = nil, project = nil, names = {} }

--- Agent pane right of the pane in window `parent`, for the agents of
--- `workspace` of `project`, every workspace of `project` when there is no
--- `workspace`, or every project when there is neither. `agents` is the agent
--- on each line as last read from the servers.
H.agents = { win = nil, buf = nil, agents = {} }

H.is_open = function(win) return win ~= nil and vim.api.nvim_win_is_valid(win) end

H.close_agents = function()
  if H.is_open(H.agents.win) then vim.api.nvim_win_close(H.agents.win, true) end
  H.agents = { win = nil, buf = nil, agents = {} }
end

H.close_workspaces = function()
  H.close_agents()
  if H.is_open(H.workspaces.win) then
    vim.api.nvim_win_close(H.workspaces.win, true)
  end
  H.workspaces = { win = nil, buf = nil, project = nil, names = {} }
end

H.close = function()
  H.close_workspaces()
  if H.is_open(H.projects.win) then vim.api.nvim_win_close(H.projects.win, true) end
  H.projects = { win = nil, buf = nil, names = {} }
end

--- Sets window options shared by both panes.
H.style = function(win)
  vim.wo[win][0].wrap = false
  vim.wo[win][0].number = false
  vim.wo[win][0].relativenumber = false
  vim.wo[win][0].signcolumn = 'no'
  vim.wo[win][0].cursorline = true
end

H.map = function(buf, lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { buffer = buf, nowait = true, desc = desc })
end

--- Closes every pane once focus moves to a window that is not one of them, so
--- a float is never left sitting over the window that took focus.
H.close_on_leave = function(buf)
  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = buf,
    desc = 'Close the explorer',
    callback = function()
      vim.schedule(function()
        local cur = vim.api.nvim_get_current_win()
        local panes = { H.projects.win, H.workspaces.win, H.agents.win }
        if not vim.tbl_contains(panes, cur) then H.close() end
      end)
    end,
  })
end

--- Shows whether a server is running, ahead of the text on line `lnum`.
H.glyph = function(buf, lnum, running)
  vim.api.nvim_buf_set_extmark(buf, H.ns, lnum, 0, {
    virt_text = {
      { running and '● ' or '○ ', running and 'DiagnosticOk' or 'Comment' },
    },
    virt_text_pos = 'inline',
  })
end

--- Width of a line showing `name` and then `detail` at the end of the line.
H.width = function(name, detail)
  return vim.fn.strdisplaywidth(name) + 2 + vim.fn.strdisplaywidth(detail)
end

--- Fits `win` to its content, keeping it on screen.
H.resize = function(win, width, height)
  vim.api.nvim_win_set_config(win, {
    width = math.max(math.min(width + 1, vim.o.columns - 4), 20),
    height = math.max(math.min(height, vim.o.lines - 6), 1),
  })
  -- an edit that adds a line scrolls the window before it grows to fit, which
  -- hides the first line; show it again once every line fits
  local lines = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
  if lines <= vim.api.nvim_win_get_height(win) then
    vim.api.nvim_win_call(win, function() vim.fn.winrestview({ topline = 1 }) end)
  end
end

-- Project pane ---------------------------------------------------------------

--- Connects to the default workspace of the project under the cursor. The
--- pane closes first, so it is not still open when the UI comes back to this
--- server. An edited line names no project, so it does nothing.
H.connect = function()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local name = H.project_under_cursor()
  if not name then return end
  H.close()
  -- already here; `:connect` to our own server would go nowhere
  if lnum == projects.current_index() then return end
  vim.schedule(function() projects.connect(name) end)
end

--- The project on the cursor line, unless the line was edited since it was
--- listed.
--- @return string?
H.project_under_cursor = function()
  local name = H.projects.names[vim.api.nvim_win_get_cursor(0)[1]]
  if name and vim.trim(vim.api.nvim_get_current_line()) == name then return name end
end

--- Lists the projects from the store, dropping any unsynced edits.
--- @param buf integer
--- @return integer width widest line, glyph and path included
H.render_projects = function(buf)
  local names = projects.names()
  H.projects.names = names
  local current = projects.current_index()

  vim.api.nvim_buf_clear_namespace(buf, H.ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, names)
  vim.bo[buf].modified = false

  local paths = projects.paths()
  local width = 0
  for i, name in ipairs(names) do
    local path = vim.fn.fnamemodify(paths[i], ':~')
    H.glyph(buf, i - 1, projects.status(name) == 'running')
    vim.api.nvim_buf_set_extmark(buf, H.ns, i - 1, 0, {
      end_col = #name,
      hl_group = i == current and 'Title' or nil,
      virt_text = { { '  ' .. path, 'Comment' } },
      virt_text_pos = 'eol',
    })
    width = math.max(width, 2 + H.width(name, path))
  end
  H.projects.width = width
  if H.is_open(H.projects.win) then H.resize(H.projects.win, width, #names) end
  return width
end

--- Lines of `buf` matched against the `known` names they were listed as. A
--- line whose text is a known name keeps it; the names no line keeps were
--- deleted, and the other lines are new.
--- @param buf integer
--- @param known string[]
--- @return string[] removed, string[] added
H.diff_names = function(buf, known)
  local kept, added = {}, {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local name = vim.trim(line)
    if vim.tbl_contains(known, name) then
      kept[name] = true
    elseif name ~= '' and not vim.tbl_contains(added, name) then
      added[#added + 1] = name
    end
  end
  local removed = vim.tbl_filter(function(n) return not kept[n] end, known)
  return removed, added
end

--- Asks to apply `changes`, one `{ action, name }` per line of the prompt the
--- way 'mini.files' lists them. True when there is nothing to ask about.
--- @param title string
--- @param changes string[][]
--- @return boolean
H.confirm = function(title, changes)
  if #changes == 0 then return true end
  local lines = vim.tbl_map(
    function(c) return ('  %s │ %s'):format(c[1], c[2]) end,
    changes
  )
  local msg = ('%s\n\n%s'):format(title, table.concat(lines, '\n'))
  return vim.fn.confirm(msg, '&Yes\n&No', 1, 'Question') == 1
end

--- Removes every project whose line was deleted from the list, after asking,
--- stopping its servers. Nothing on disk is touched. The current project is
--- where this nvim runs, so it is not removed. New lines are not projects to
--- add; that takes a folder, which `:ProjectAdd` picks.
H.synchronize_projects = function()
  local p = H.projects
  local removed, added = H.diff_names(p.buf, p.names)
  local current = p.names[projects.current_index() or 0]
  if vim.tbl_contains(removed, current) then
    vim.notify("explorer: can't remove the current project; kept " .. current, vim.log.levels.WARN)
    removed = vim.tbl_filter(function(n) return n ~= current end, removed)
  end
  if #added > 0 then
    vim.notify(
      'explorer: adding projects is not supported, use :ProjectAdd; ignored '
        .. table.concat(added, ', '),
      vim.log.levels.WARN
    )
  end
  local changes = vim.tbl_map(function(n) return { 'DELETE', n } end, removed)
  if not H.confirm('Synchronize projects?', changes) then return end
  for _, name in ipairs(removed) do
    projects.remove(name)
  end
  -- panes right of this one may show a project that is gone
  if #removed > 0 then H.close_workspaces() end
  H.render_projects(p.buf)
end

-- Workspace pane -------------------------------------------------------------

--- True when this nvim is in workspace `ws` of project `name`.
H.is_current = function(name, ws)
  return projects.current_name() == name and projects.current_workspace() == ws
end

--- Lists the workspaces of the pane's project from jj, dropping any unsynced
--- edits. Returns false when the project has none to list.
--- @return boolean
H.render_workspaces = function()
  local ws = H.workspaces
  local list = projects.workspaces(ws.project)
  if not list then return false end

  ws.names = vim.tbl_map(function(w) return w.name end, list)
  vim.api.nvim_buf_clear_namespace(ws.buf, H.ns, 0, -1)
  vim.api.nvim_buf_set_lines(ws.buf, 0, -1, false, ws.names)
  vim.bo[ws.buf].modified = false

  local width = 0
  for i, w in ipairs(list) do
    local path = vim.fn.fnamemodify(w.path, ':~')
    H.glyph(ws.buf, i - 1, projects.status(ws.project, w.name) == 'running')
    vim.api.nvim_buf_set_extmark(ws.buf, H.ns, i - 1, 0, {
      end_col = #w.name,
      hl_group = H.is_current(ws.project, w.name) and 'Title' or nil,
      virt_text = { { '  ' .. path, 'Comment' } },
      virt_text_pos = 'eol',
    })
    width = math.max(width, 2 + H.width(w.name, path))
  end
  ws.width = width
  if H.is_open(ws.win) then H.resize(ws.win, width, #list) end
  return true
end

--- Creates a workspace for every line that names none yet and removes every
--- one whose line was deleted, after asking, the way 'mini.files'
--- synchronizes. Then re-lists from jj. `default` is the project's own folder
--- and the current workspace is where this nvim runs, so neither is removed.
H.synchronize = function()
  local ws = H.workspaces
  local removed, create = H.diff_names(ws.buf, ws.names)

  local kept = vim.tbl_filter(
    function(n) return n == 'default' or H.is_current(ws.project, n) end,
    removed
  )
  if #kept > 0 then
    vim.notify(
      "explorer: can't remove the default or current workspace; kept "
        .. table.concat(kept, ', '),
      vim.log.levels.WARN
    )
  end
  local delete = vim.tbl_filter(function(n) return not vim.tbl_contains(kept, n) end, removed)

  local changes = {}
  for _, name in ipairs(delete) do
    changes[#changes + 1] = { 'DELETE', name }
  end
  for _, name in ipairs(create) do
    changes[#changes + 1] = { 'CREATE', name }
  end
  local title = ('Synchronize workspaces of %s?'):format(ws.project)
  if not H.confirm(title, changes) then return end
  for _, name in ipairs(delete) do
    projects.remove_workspace(ws.project, name)
  end
  for _, name in ipairs(create) do
    projects.add_workspace(ws.project, name)
  end
  -- an agent pane over a removed workspace lists nothing that still exists
  if vim.tbl_contains(delete, H.agents.workspace) then H.close_agents() end
  H.render_workspaces()
end

--- Connects to the server of the workspace under the cursor, starting it if
--- needed. A line that is not synced yet names no workspace, so it does
--- nothing.
H.connect_workspace = function()
  local ws = H.workspaces
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.trim(vim.api.nvim_get_current_line())
  local project, name = ws.project, ws.names[lnum]
  if not name or line ~= name then return end
  H.close()
  -- already here; `:connect` to our own server would go nowhere
  if H.is_current(project, name) then return end
  vim.schedule(function() projects.connect(project, name) end)
end

--- Grows `win` with the lines of `buf` as they are typed, so new lines are not
--- scrolled out of view. Never narrower than `min_width()`.
H.grow_with_edits = function(buf, win, min_width)
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = function()
      if not H.is_open(win) then return end
      local width = min_width()
      for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        width = math.max(width, vim.fn.strdisplaywidth(l))
      end
      H.resize(win, width, vim.api.nvim_buf_line_count(buf))
    end,
  })
end

--- Opens the workspace pane right of the project pane, for the project under
--- the cursor.
H.open_workspaces = function()
  local name = H.project_under_cursor()
  if not name then return end
  H.close_workspaces()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'huey://workspaces/' .. name)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'hueyexplorer'
  H.workspaces = { buf = buf, project = name, names = {} }
  if not H.render_workspaces() then
    vim.api.nvim_buf_delete(buf, { force = true })
    H.workspaces = { names = {} }
    vim.notify(('explorer: %s is not a jj repo'):format(name), vim.log.levels.WARN)
    return
  end

  local left = vim.api.nvim_win_get_config(H.projects.win)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = left.row,
    -- past the left pane and its border
    col = left.col + left.width + 2,
    width = 20,
    height = 1,
  })
  H.workspaces.win = win
  H.resize(win, H.workspaces.width, #H.workspaces.names)
  H.style(win)

  H.map(buf, '<CR>', H.connect_workspace, 'Connect to workspace')
  H.map(buf, '=', H.synchronize, 'Synchronize workspaces')
  H.map(buf, 'l', H.open_agents, 'Agents')
  H.map(buf, '<Tab>', H.toggle_project_agents, 'Agents of the project')
  H.map(buf, 'h', H.back, 'Back to projects')
  H.map(buf, 'q', H.close, 'Close')
  H.grow_with_edits(buf, win, function() return H.workspaces.width or 0 end)
  H.close_on_leave(buf)
end

-- Agent pane -----------------------------------------------------------------

--- True when the pane lists one workspace, so new lines can start agents
--- there. A pane over several workspaces has nowhere to start one, though its
--- lines can still be deleted.
H.can_start_agents = function() return H.agents.workspace ~= nil end

--- Lists the pane's agents from their servers, dropping any unsynced edits. A
--- line shows what the agent says it is working on, or its prompt until it
--- says. After it come the workspace it runs in, in a pane over several, and
--- the prompt it started with, dimmed, once that differs from the line.
H.render_agents = function()
  local a = H.agents
  if a.workspace then
    a.agents = projects.agents(a.project, a.workspace)
  else
    a.agents = projects.all_agents(a.project)
  end
  local single = H.can_start_agents()
  vim.api.nvim_buf_clear_namespace(a.buf, H.ns, 0, -1)
  vim.api.nvim_buf_set_lines(
    a.buf,
    0,
    -1,
    false,
    vim.tbl_map(function(g) return g.text end, a.agents)
  )
  vim.bo[a.buf].modified = false

  local width = 0
  for i, g in ipairs(a.agents) do
    vim.api.nvim_buf_set_extmark(a.buf, H.ns, i - 1, 0, {
      virt_text = { { g.icon .. ' ', 'Special' } },
      virt_text_pos = 'inline',
    })
    local chunks = {}
    if not single then
      chunks[#chunks + 1] = { '  ' .. projects.label(g.project, g.workspace), 'Directory' }
    end
    if g.prompt and g.prompt ~= g.text then
      chunks[#chunks + 1] = { '  ' .. g.prompt, 'Comment' }
    end
    local detail = table.concat(vim.tbl_map(function(c) return c[1] end, chunks))
    if #chunks > 0 then
      vim.api.nvim_buf_set_extmark(a.buf, H.ns, i - 1, 0, {
        virt_text = chunks,
        virt_text_pos = 'eol',
      })
    end
    width = math.max(width, 2 + vim.fn.strdisplaywidth(g.text .. detail))
  end
  if #a.agents == 0 and not single then
    vim.api.nvim_buf_set_extmark(a.buf, H.ns, 0, 0, {
      virt_text = { { 'no agents running', 'Comment' } },
      virt_text_pos = 'eol',
    })
  end
  -- room to type a prompt in an empty pane
  a.width = math.max(width, 30)
  if H.is_open(a.win) then
    H.resize(a.win, a.width, math.max(#a.agents, 1))
  end
end

--- The agent on the cursor line, unless the line was edited since it was
--- listed.
--- @return huey.ProjectAgent?
H.agent_under_cursor = function()
  local a = H.agents
  if not H.is_open(a.win) then return end
  local lnum = vim.api.nvim_win_get_cursor(a.win)[1]
  local agent = a.agents[lnum]
  local line = vim.api.nvim_buf_get_lines(a.buf, lnum - 1, lnum, false)[1]
  if agent and line == agent.text then return agent end
end

--- Starts an agent for every line that matches none listed, with the line as
--- its prompt, and stops every agent whose line was deleted, after asking.
--- Then re-lists from the servers; the pane's own is started if it was not
--- running. Agents can share a line's text, so lines are matched by count:
--- with two lines alike and one deleted, the later agent is the one stopped.
H.synchronize_agents = function()
  local a = H.agents
  -- how many listed agents each line can still match
  local left, create = {}, {}
  for _, g in ipairs(a.agents) do
    left[g.text] = (left[g.text] or 0) + 1
  end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(a.buf, 0, -1, false)) do
    local prompt = vim.trim(line)
    if (left[prompt] or 0) > 0 then
      left[prompt] = left[prompt] - 1
    elseif prompt ~= '' and not vim.tbl_contains(create, prompt) then
      create[#create + 1] = prompt
    end
  end
  local removed = {}
  for i = #a.agents, 1, -1 do
    local g = a.agents[i]
    if (left[g.text] or 0) > 0 then
      left[g.text] = left[g.text] - 1
      table.insert(removed, 1, g)
    end
  end

  if #create > 0 and not H.can_start_agents() then
    vim.notify(
      'explorer: agents start in one workspace, open its agents with l; ignored '
        .. table.concat(create, ', '),
      vim.log.levels.WARN
    )
    create = {}
  end

  local changes = {}
  for _, g in ipairs(removed) do
    local where = H.can_start_agents() and ''
      or ('  (%s)'):format(projects.label(g.project, g.workspace))
    changes[#changes + 1] = { 'DELETE', g.text .. where }
  end
  for _, prompt in ipairs(create) do
    changes[#changes + 1] = { 'CREATE', prompt }
  end
  if not H.confirm(('Synchronize agents of %s?'):format(a.label), changes) then
    return
  end
  for _, g in ipairs(removed) do
    projects.remove_agent(g.project, g.workspace, g.bufnr)
  end
  for _, prompt in ipairs(create) do
    projects.add_agent(a.project, a.workspace, prompt)
  end
  -- the server may have just started
  if #create > 0 and H.is_open(H.workspaces.win) then H.render_workspaces() end
  H.render_agents()
end

--- Shows the terminal of the agent under the cursor, connecting to its server
--- when it is another one. A line that is not synced yet does nothing.
H.open_agent = function()
  local agent = H.agent_under_cursor()
  if not agent then return end
  H.close()
  vim.schedule(
    function() projects.open_agent(agent.project, agent.workspace, agent.bufnr) end
  )
end

--- Opens an agent pane right of the current pane and focuses it. `project`
--- and `workspace` narrow it as described at `H.agents`.
--- @param project string?
--- @param workspace string?
H.open_agents_pane = function(project, workspace)
  local parent = vim.api.nvim_get_current_win()
  local label
  if workspace then
    label = projects.label(project, workspace)
  else
    label = (project and project .. '/' or '') .. '*'
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'huey://agents/' .. label)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'hueyexplorer'
  H.agents = {
    buf = buf,
    parent = parent,
    project = project,
    workspace = workspace,
    label = label,
    agents = {},
  }
  H.render_agents()

  local left = vim.api.nvim_win_get_config(parent)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = left.row,
    col = left.col + left.width + 2,
    width = 20,
    height = 1,
  })
  H.agents.win = win
  H.resize(win, H.agents.width, math.max(#H.agents.agents, 1))
  H.style(win)

  H.map(buf, '<CR>', H.open_agent, 'Open agent')
  H.map(buf, '=', H.synchronize_agents, 'Synchronize agents')
  H.map(buf, 'h', H.back_from_agents, 'Back')
  H.map(buf, 'q', H.close, 'Close')
  -- agent panes are the last level; <Tab> would otherwise jump in the jumplist
  H.map(buf, '<Tab>', '<Nop>', 'Nothing')
  H.grow_with_edits(buf, win, function() return H.agents.width or 0 end)
  H.close_on_leave(buf)
end

--- Opens the agent pane right of the workspace pane, for the workspace under
--- the cursor. Unsynced lines name no workspace yet, so they do nothing.
H.open_agents = function()
  local ws = H.workspaces
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local name = ws.names[lnum]
  if not name or vim.trim(vim.api.nvim_get_current_line()) ~= name then return end
  H.close_agents()
  H.open_agents_pane(ws.project, name)
end

--- True when the agent pane is open right of the current window and lists
--- every workspace of `project`, or every project when nil.
H.is_toggled = function(project)
  local a = H.agents
  return H.is_open(a.win)
    and a.parent == vim.api.nvim_get_current_win()
    and a.workspace == nil
    and a.project == project
end

--- Opens the agents of every project right of the project pane, in place of
--- the workspace pane, or closes them when they are open.
H.toggle_all_agents = function()
  if H.is_toggled(nil) then return H.close_agents() end
  H.close_workspaces()
  H.open_agents_pane()
end

--- Opens the agents of every workspace of the pane's project right of the
--- workspace pane, or closes them when they are open.
H.toggle_project_agents = function()
  local project = H.workspaces.project
  if H.is_toggled(project) then return H.close_agents() end
  H.close_agents()
  H.open_agents_pane(project)
end

--- Returns to the pane the agent pane opened from, closing it.
H.back_from_agents = function()
  if H.is_open(H.agents.parent) then vim.api.nvim_set_current_win(H.agents.parent) end
  H.close_agents()
end

--- Returns to the project pane, closing the workspace pane.
H.back = function()
  if H.is_open(H.projects.win) then vim.api.nvim_set_current_win(H.projects.win) end
  H.close_workspaces()
end

--- Opens the project pane in the top left corner, with the cursor on the
--- current project. Focuses it when it is already open.
Explorer.open = function()
  if H.is_open(H.projects.win) then
    return vim.api.nvim_set_current_win(H.projects.win)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'huey://projects')
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'hueyexplorer'
  H.projects.buf = buf
  local width = H.render_projects(buf)
  local count = #H.projects.names

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = 1,
    col = 0,
    width = 20,
    height = 1,
  })
  H.projects.win = win
  H.resize(win, width, count)
  H.style(win)
  vim.api.nvim_win_set_cursor(
    win,
    { math.min(projects.current_index() or 1, math.max(count, 1)), 0 }
  )

  H.map(buf, '<CR>', H.connect, 'Connect to project')
  H.map(buf, '=', H.synchronize_projects, 'Synchronize projects')
  H.map(buf, 'l', H.open_workspaces, 'Workspaces')
  H.map(buf, '<Tab>', H.toggle_all_agents, 'Agents of every project')
  H.map(buf, 'q', H.close, 'Close')
  H.map(buf, '<Esc>', H.close, 'Close')
  H.grow_with_edits(buf, win, function() return H.projects.width or 0 end)
  H.close_on_leave(buf)
end

return Explorer
