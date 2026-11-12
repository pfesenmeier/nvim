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
-- agent's terminal is deleted. `<Tab>` swaps the project pane for the agents
-- of every project, or the workspace pane for the agents of every workspace of
-- the project; press it again to swap back. Agent panes show each agent's
-- state and how long it has been in it. Every project and workspace line
-- counts its agents by state, and every pane keeps up with the agents while it
-- is open. When the panes don't all fit across the screen, the ones on the
-- left are hidden until there is room again, as in 'mini.files'.
-- `Explorer.open_agents()` opens straight to the agents of the current
-- project. See 'lua/huey/projects'.
local projects = require('huey.projects')
local proto = require('huey.hub.proto')
local View = require('huey.hub.view')

local Explorer = {}
local H = {}

H.ns = vim.api.nvim_create_namespace('HueyExplorer')

--- Project pane; `names` is the project name on each line as last read from
--- the store
H.projects = { win = nil, buf = nil, names = {} }

--- Workspace pane for `project`; `names` is the workspace on each line as last
--- read from jj
H.workspaces = { win = nil, buf = nil, project = nil, names = {} }

--- Agent pane for the agents of `workspace` of `project`, every workspace of
--- `project` when there is no `workspace`, or every project when there is
--- neither. It opens from the pane in window `parent`: right of it for one
--- workspace, or in its place for several, hiding it until the agent pane
--- closes. `agents` is the agent on each line as last read from the servers.
H.agents = { win = nil, buf = nil, agents = {} }

--- Every agent in a running server as last read, and the timer that re-reads
--- them while the explorer is open.
H.all = {}
H.timer = nil

local refresh_ms = 1000

H.is_open = function(win) return win ~= nil and vim.api.nvim_win_is_valid(win) end

--- Focuses `win`, showing it first if `H.layout()` hid it; a hidden window
--- can't take focus.
H.focus = function(win)
  vim.api.nvim_win_set_config(win, { hide = false })
  vim.api.nvim_set_current_win(win)
end

--- Places the open panes side by side from the left edge of the screen. When
--- they don't all fit, the focused pane stays shown along with as many of its
--- neighbours as fit, left ones first, and the rest are hidden, the way
--- 'mini.files' does. A pane an agent pane stands in for stays hidden.
H.layout = function()
  local a = H.agents
  local wins = vim.tbl_filter(
    function(win) return H.is_open(win) and not (a.replaced and win == a.parent) end,
    { H.projects.win, H.workspaces.win, a.win }
  )
  if #wins == 0 then return end
  -- the current window, or the rightmost pane when focus is elsewhere
  local focus = #wins
  for i, win in ipairs(wins) do
    if win == vim.api.nvim_get_current_win() then focus = i end
  end
  -- each pane's width plus its border
  local widths = vim.tbl_map(
    function(win) return vim.api.nvim_win_get_config(win).width + 2 end,
    wins
  )

  local from, to, used = focus, focus, widths[focus]
  while from > 1 and used + widths[from - 1] <= vim.o.columns do
    from = from - 1
    used = used + widths[from]
  end
  while to < #wins and used + widths[to + 1] <= vim.o.columns do
    to = to + 1
    used = used + widths[to]
  end

  local col = 0
  for i, win in ipairs(wins) do
    if i < from or i > to then
      vim.api.nvim_win_set_config(win, { hide = true })
    else
      local row = vim.api.nvim_win_get_config(win).row
      vim.api.nvim_win_set_config(win, { relative = 'editor', row = row, col = col, hide = false })
      col = col + widths[i]
    end
  end
end

H.close_agents = function()
  local a = H.agents
  if H.is_open(a.win) then vim.api.nvim_win_close(a.win, true) end
  -- the pane it stood in for shows again
  if a.replaced and H.is_open(a.parent) then
    vim.api.nvim_win_set_config(a.parent, { hide = false })
  end
  H.agents = { win = nil, buf = nil, agents = {} }
  H.layout()
end

H.close_workspaces = function()
  H.close_agents()
  if H.is_open(H.workspaces.win) then
    vim.api.nvim_win_close(H.workspaces.win, true)
  end
  H.workspaces = { win = nil, buf = nil, project = nil, names = {} }
  H.layout()
end

H.close = function()
  H.close_workspaces()
  if H.is_open(H.projects.win) then vim.api.nvim_win_close(H.projects.win, true) end
  H.projects = { win = nil, buf = nil, names = {} }
  if H.timer and not H.timer:is_closing() then
    H.timer:stop()
    H.timer:close()
  end
  H.timer, H.all = nil, {}
  pcall(vim.api.nvim_del_augroup_by_name, 'HueyExplorerLayout')
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

--- Re-reads every agent from the running servers.
H.fetch = function() H.all = projects.all_agents() end

--- Agents of `project` from the last read, only those in `workspace` when
--- given, or of every project when `project` is nil.
--- @param project string?
--- @param workspace string?
--- @return huey.ProjectAgent[]
H.agents_in = function(project, workspace)
  return vim.tbl_filter(function(g)
    return (project == nil or g.project == project)
      and (workspace == nil or g.workspace == workspace)
  end, H.all)
end

--- Virtual text counting `agents` by state, most urgent first, e.g. `⏸1 ∿2`.
--- An agent with no status yet counts as idle. Empty when there are none.
--- @param agents huey.ProjectAgent[]
--- @return string[][]
H.tally = function(agents)
  local counts = {}
  for _, g in ipairs(agents) do
    local state = g.state or 'idle'
    counts[state] = (counts[state] or 0) + 1
  end
  local chunks = {}
  for _, state in ipairs(proto.states) do
    if counts[state] then
      local sep = #chunks == 0 and '  ' or ' '
      chunks[#chunks + 1] = { sep .. proto.icon(state) .. counts[state], proto.hl[state] }
    end
  end
  return chunks
end

--- Marks line `lnum` of `buf`: whether its server is running ahead of the
--- text, which is highlighted when `current`, and after it the tally of
--- `agents` and then `path`. Returns the width the line takes.
H.decorate = function(buf, lnum, text, running, current, agents, path)
  H.glyph(buf, lnum, running)
  local virt_text = H.tally(agents)
  virt_text[#virt_text + 1] = { '  ' .. path, 'Comment' }
  vim.api.nvim_buf_set_extmark(buf, H.ns, lnum, 0, {
    end_col = #text,
    hl_group = current and 'Title' or nil,
    virt_text = virt_text,
    virt_text_pos = 'eol',
  })
  local detail = table.concat(vim.tbl_map(function(c) return c[1] end, virt_text))
  return 2 + vim.fn.strdisplaywidth(text .. detail)
end

--- Fits `win` to its content, keeping it on screen, and lays the panes out
--- again for its new width.
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
  H.layout()
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
  H.projects.buf = buf
  H.projects.names = names
  H.projects.paths = projects.paths()
  H.projects.running = vim.tbl_map(
    function(name) return projects.status(name) == 'running' end,
    names
  )
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, names)
  vim.bo[buf].modified = false
  return H.mark_projects()
end

--- Marks every line of the project pane, as `H.decorate()` does, from what
--- was last read. Fits the pane to the result.
--- @return integer width widest line, glyph and details included
H.mark_projects = function()
  local p = H.projects
  local current = projects.current_index()
  vim.api.nvim_buf_clear_namespace(p.buf, H.ns, 0, -1)
  local width = 0
  for i, name in ipairs(p.names) do
    local path = vim.fn.fnamemodify(p.paths[i], ':~')
    local agents = H.agents_in(name)
    width = math.max(width, H.decorate(p.buf, i - 1, name, p.running[i], i == current, agents, path))
  end
  p.width = width
  if H.is_open(p.win) then H.resize(p.win, width, #p.names) end
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
  ws.paths = vim.tbl_map(function(w) return w.path end, list)
  ws.running = vim.tbl_map(
    function(w) return projects.status(ws.project, w.name) == 'running' end,
    list
  )
  vim.api.nvim_buf_set_lines(ws.buf, 0, -1, false, ws.names)
  vim.bo[ws.buf].modified = false
  H.mark_workspaces()
  return true
end

--- Marks every line of the workspace pane, as `H.decorate()` does, from what
--- was last read. Fits the pane to the result.
H.mark_workspaces = function()
  local ws = H.workspaces
  vim.api.nvim_buf_clear_namespace(ws.buf, H.ns, 0, -1)
  local width = 0
  for i, name in ipairs(ws.names) do
    local path = vim.fn.fnamemodify(ws.paths[i], ':~')
    local current = H.is_current(ws.project, name)
    local agents = H.agents_in(ws.project, name)
    width = math.max(width, H.decorate(ws.buf, i - 1, name, ws.running[i], current, agents, path))
  end
  ws.width = width
  if H.is_open(ws.win) then H.resize(ws.win, width, #ws.names) end
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
    -- `H.layout()` moves it right of the project pane
    col = 0,
    width = 20,
    height = 1,
  })
  H.workspaces.win = win
  H.resize(win, H.workspaces.width, #H.workspaces.names)
  H.style(win)

  H.map(buf, '<CR>', H.connect_workspace, 'Connect to workspace')
  H.map(buf, '=', H.synchronize, 'Synchronize workspaces')
  H.map(buf, 'l', H.open_agents, 'Agents')
  H.map(buf, '<Tab>', H.show_project_agents, 'Agents of the project')
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

-- Longest an agent's line and its dimmed prompt get, so a long title or
-- prompt does not stretch the pane across the screen
local agent_max_width = 50
local prompt_max_width = 30

--- `text` cut to `max` display cells, ending in an ellipsis when cut.
H.truncate = function(text, max)
  if vim.fn.strdisplaywidth(text) <= max then return text end
  local cut = text
  while vim.fn.strdisplaywidth(cut) > max - 1 do
    cut = vim.fn.strcharpart(cut, 0, vim.fn.strchars(cut) - 1)
  end
  return cut .. '…'
end

--- Columns shown ahead of an agent's line: its icon and state, how long it
--- has been in that state, how long it has been running, and the workspace it
--- runs in when `widths.workspace` is set. Padded to `widths` so the lines
--- below each other line up.
--- @param g huey.ProjectAgent
--- @param widths { state: integer, workspace: integer? }
--- @param now integer epoch seconds
--- @return [string, string][] chunks
H.agent_columns = function(g, widths, now)
  local hl = View.state_hl[g.state] or 'Comment'
  local chunks = { { g.icon .. ' ', hl } }
  if widths.state > 0 then
    local state = g.state and View.state(g) or ''
    local since = function(t) return ('%3s'):format(t and View.ago(now - t) or '') end
    chunks[#chunks + 1] = { View.pad(state, widths.state) .. ' ', hl }
    chunks[#chunks + 1] = { since(g.changed) .. ' ' .. since(g.started) .. '  ', 'Comment' }
  end
  if widths.workspace then
    local label = projects.label(g.project, g.workspace)
    chunks[#chunks + 1] = { View.pad(label, widths.workspace) .. '  ', 'Directory' }
  end
  return chunks
end

--- Lists the pane's agents from the last read, dropping any unsynced edits. A
--- line shows what the agent says it is working on, or its prompt until it
--- says. Ahead of it come the columns of `H.agent_columns()`, and after it why
--- the agent is blocked and the prompt it started with, dimmed, once that
--- differs from the line. Long lines and prompts are cut short; `line` is what
--- each agent's line shows.
H.render_agents = function()
  local a = H.agents
  a.agents = H.agents_in(a.project, a.workspace)
  local single = H.can_start_agents()
  local now = os.time()
  local widths = { state = 0, workspace = not single and 0 or nil }
  for _, g in ipairs(a.agents) do
    g.line = H.truncate(g.text, agent_max_width)
    if g.state then widths.state = math.max(widths.state, #View.state(g)) end
    if widths.workspace then
      widths.workspace =
        math.max(widths.workspace, vim.fn.strdisplaywidth(projects.label(g.project, g.workspace)))
    end
  end

  vim.api.nvim_buf_clear_namespace(a.buf, H.ns, 0, -1)
  -- a re-list is not an edit to undo
  local undolevels = vim.bo[a.buf].undolevels
  vim.bo[a.buf].undolevels = -1
  vim.api.nvim_buf_set_lines(
    a.buf,
    0,
    -1,
    false,
    vim.tbl_map(function(g) return g.line end, a.agents)
  )
  vim.bo[a.buf].undolevels = undolevels
  vim.bo[a.buf].modified = false

  local width = 0
  for i, g in ipairs(a.agents) do
    local columns = H.agent_columns(g, widths, now)
    vim.api.nvim_buf_set_extmark(a.buf, H.ns, i - 1, 0, {
      virt_text = columns,
      virt_text_pos = 'inline',
    })
    local chunks = {}
    if g.state == 'blocked' and g.msg and g.msg ~= '' then
      chunks[#chunks + 1] = { '  ' .. (g.msg:gsub('%c', ' ')), 'DiagnosticWarn' }
    end
    if g.prompt and g.prompt ~= g.text then
      chunks[#chunks + 1] = { '  ' .. H.truncate(g.prompt, prompt_max_width), 'Comment' }
    end
    if #chunks > 0 then
      vim.api.nvim_buf_set_extmark(a.buf, H.ns, i - 1, 0, {
        virt_text = chunks,
        virt_text_pos = 'eol',
      })
    end
    local all = vim.list_extend(vim.list_extend({}, columns), chunks)
    local line = table.concat(vim.tbl_map(function(c) return c[1] end, all))
    width = math.max(width, vim.fn.strdisplaywidth(g.line .. line))
  end
  if #a.agents == 0 and not single then
    vim.api.nvim_buf_set_extmark(a.buf, H.ns, 0, 0, {
      virt_text = { { 'no agents running', 'Comment' } },
      virt_text_pos = 'eol',
    })
  end
  -- room to type a prompt in an empty pane
  a.width = math.max(width, 30)
  if H.is_open(a.win) then H.resize(a.win, a.width, math.max(#a.agents, 1)) end
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
  if agent and line == agent.line then return agent end
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
    left[g.line] = (left[g.line] or 0) + 1
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
    if (left[g.line] or 0) > 0 then
      left[g.line] = left[g.line] - 1
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
  H.fetch()
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

--- Opens an agent pane from the current pane and focuses it. `project` and
--- `workspace` narrow it as described at `H.agents`. A pane over one workspace
--- opens right of the current pane; one over several takes its place.
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

  local replaced = workspace == nil

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'huey://agents/' .. label)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'hueyexplorer'
  H.agents = {
    buf = buf,
    parent = parent,
    replaced = replaced,
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
    -- `H.layout()` moves it right of its parent, or into its place
    col = 0,
    width = 20,
    height = 1,
  })
  if replaced then vim.api.nvim_win_set_config(parent, { hide = true }) end
  H.agents.win = win
  H.resize(win, H.agents.width, math.max(#H.agents.agents, 1))
  H.style(win)

  H.map(buf, '<CR>', H.open_agent, 'Open agent')
  H.map(buf, '=', H.synchronize_agents, 'Synchronize agents')
  H.map(buf, 'h', H.back_from_agents, 'Back')
  H.map(buf, 'q', H.close, 'Close')
  if replaced then
    H.map(buf, '<Tab>', H.back_from_agents, 'Back')
  else
    -- agent panes are the last level; <Tab> would otherwise jump in the jumplist
    H.map(buf, '<Tab>', '<Nop>', 'Nothing')
  end
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

--- Swaps the project pane for the agents of every project, closing the
--- workspace pane.
H.show_all_agents = function()
  H.close_workspaces()
  H.open_agents_pane()
end

--- Swaps the workspace pane for the agents of every workspace of its project,
--- closing the agents of a single workspace if open.
H.show_project_agents = function()
  H.close_agents()
  H.open_agents_pane(H.workspaces.project)
end

--- Returns to the pane the agent pane opened from, closing it.
H.back_from_agents = function()
  local parent = H.agents.parent
  if H.is_open(parent) then H.focus(parent) end
  H.close_agents()
end

--- Returns to the project pane, closing the workspace pane.
H.back = function()
  if H.is_open(H.projects.win) then H.focus(H.projects.win) end
  H.close_workspaces()
end

--- True when `pane` is open and still shows exactly the `listed` lines, so a
--- redraw drops no edits. 'modified' is never set in a scratch buffer.
--- @param listed string[]
H.is_untouched = function(pane, listed)
  if not H.is_open(pane.win) then return false end
  local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
  -- an empty pane still has its one empty line
  if #listed == 0 then return #lines == 1 and lines[1] == '' end
  return vim.deep_equal(lines, listed)
end

--- Re-reads the agents and redraws every pane with them, so tallies, states
--- and times stay current. Waits while a pane is being typed in or has
--- unsynced edits, so they are never dropped. The agent pane keeps the cursor
--- on the agent it was on.
H.refresh = function()
  if not H.is_open(H.projects.win) then return H.close() end
  if vim.api.nvim_get_mode().mode:sub(1, 1) ~= 'n' then return end
  H.fetch()
  if H.is_untouched(H.projects, H.projects.names) then H.mark_projects() end
  if H.is_untouched(H.workspaces, H.workspaces.names) then H.mark_workspaces() end

  local a = H.agents
  local lines = vim.tbl_map(function(g) return g.line end, a.agents)
  if not H.is_untouched(a, lines) then return end
  local was = H.agent_under_cursor()
  H.render_agents()
  for i, g in ipairs(was and a.agents or {}) do
    local same = g.project == was.project and g.workspace == was.workspace
    if same and g.bufnr == was.bufnr then vim.api.nvim_win_set_cursor(a.win, { i, 0 }) end
  end
end

--- Opens the project pane in the top left corner, with the cursor on the
--- current project. Focuses it when it is already open.
Explorer.open = function()
  if H.is_open(H.projects.win) then
    -- it may have been hidden to make room for panes right of it
    H.focus(H.projects.win)
    return H.layout()
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'huey://projects')
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'hueyexplorer'
  H.fetch()
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
  H.map(buf, '<Tab>', H.show_all_agents, 'Agents of every project')
  H.map(buf, 'q', H.close, 'Close')
  H.map(buf, '<Esc>', H.close, 'Close')
  H.grow_with_edits(buf, win, function() return H.projects.width or 0 end)
  H.close_on_leave(buf)
  vim.api.nvim_create_autocmd('VimResized', {
    group = vim.api.nvim_create_augroup('HueyExplorerLayout', { clear = true }),
    desc = 'Lay out the explorer panes again',
    callback = H.layout,
  })

  H.timer = assert(vim.uv.new_timer())
  H.timer:start(refresh_ms, refresh_ms, vim.schedule_wrap(H.refresh))
end

--- Opens the explorer on the agents of every workspace of the current
--- project, with its workspaces hidden behind them, or on the agents of every
--- project outside one. Reopens it when it is already open.
Explorer.open_agents = function()
  H.close()
  Explorer.open()
  local name = H.project_under_cursor()
  if not name or vim.api.nvim_win_get_cursor(0)[1] ~= projects.current_index() then
    return H.open_agents_pane()
  end
  -- a project that is not a jj repo has no workspace pane to open
  if projects.workspaces(name) then H.open_workspaces() end
  H.open_agents_pane(name)
end

Explorer.H = H

return Explorer
