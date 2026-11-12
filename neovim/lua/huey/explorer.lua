-- Huey explorer: floating panes for moving between projects, a la 'mini.files'.
-- The left pane lists projects: `<CR>` connects the UI to the one under the
-- cursor and `l` opens its jj workspaces in a pane to the right. There `<CR>`
-- changes the editor's directory to the workspace under the cursor. That pane
-- is editable: add a line and press `=` to create a workspace by that name. See
-- 'lua/huey/projects'.
local projects = require('huey.projects')

local Explorer = {}
local H = {}

H.ns = vim.api.nvim_create_namespace('HueyExplorer')

--- Project pane; `names` is the project name on each line
H.projects = { win = nil, names = {} }

--- Workspace pane for `project`; `names` and `paths` are the workspace on each
--- line as last read from jj
H.workspaces = { win = nil, buf = nil, project = nil, names = {}, paths = {} }

H.is_open = function(win) return win ~= nil and vim.api.nvim_win_is_valid(win) end

H.close_workspaces = function()
  if H.is_open(H.workspaces.win) then
    vim.api.nvim_win_close(H.workspaces.win, true)
  end
  H.workspaces = { win = nil, buf = nil, project = nil, names = {}, paths = {} }
end

H.close = function()
  H.close_workspaces()
  if H.is_open(H.projects.win) then vim.api.nvim_win_close(H.projects.win, true) end
  H.projects = { win = nil, names = {} }
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
        if cur ~= H.projects.win and cur ~= H.workspaces.win then H.close() end
      end)
    end,
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
end

-- Project pane ---------------------------------------------------------------

--- Connects to the project under the cursor. The pane closes first, so it is
--- not still open when the UI comes back to this server.
H.connect = function()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local name = H.projects.names[lnum]
  H.close()
  -- already here; `:connect` to our own server would go nowhere
  if not name or lnum == projects.current_index() then return end
  vim.schedule(function() projects.connect(name) end)
end

--- @param buf integer
--- @return integer width widest line, glyph and path included
H.render_projects = function(buf)
  local names = projects.names()
  H.projects.names = names
  local current = projects.current_index()

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, names)
  vim.bo[buf].modifiable = false

  local paths = projects.paths()
  local width = 0
  for i, name in ipairs(names) do
    local running = projects.status(name) == 'running'
    local path = vim.fn.fnamemodify(paths[i], ':~')
    vim.api.nvim_buf_set_extmark(buf, H.ns, i - 1, 0, {
      virt_text = {
        { running and '● ' or '○ ', running and 'DiagnosticOk' or 'Comment' },
      },
      virt_text_pos = 'inline',
    })
    vim.api.nvim_buf_set_extmark(buf, H.ns, i - 1, 0, {
      end_col = #name,
      hl_group = i == current and 'Title' or nil,
      virt_text = { { '  ' .. path, 'Comment' } },
      virt_text_pos = 'eol',
    })
    width = math.max(width, 2 + H.width(name, path))
  end
  return width
end

-- Workspace pane -------------------------------------------------------------

--- Lists the workspaces of the pane's project from jj, dropping any unsynced
--- edits. Returns false when the project has none to list.
--- @return boolean
H.render_workspaces = function()
  local ws = H.workspaces
  local list = projects.workspaces(ws.project)
  if not list then return false end

  ws.names = vim.tbl_map(function(w) return w.name end, list)
  ws.paths = vim.tbl_map(function(w) return w.path end, list)
  vim.api.nvim_buf_clear_namespace(ws.buf, H.ns, 0, -1)
  vim.api.nvim_buf_set_lines(ws.buf, 0, -1, false, ws.names)
  vim.bo[ws.buf].modified = false

  local cwd = vim.fn.resolve(vim.fn.getcwd())
  local width = 0
  for i, w in ipairs(list) do
    local path = vim.fn.fnamemodify(w.path, ':~')
    vim.api.nvim_buf_set_extmark(ws.buf, H.ns, i - 1, 0, {
      end_col = #w.name,
      hl_group = vim.fn.resolve(w.path) == cwd and 'Title' or nil,
      virt_text = { { '  ' .. path, 'Comment' } },
      virt_text_pos = 'eol',
    })
    width = math.max(width, H.width(w.name, path))
  end
  ws.width = width
  if H.is_open(ws.win) then H.resize(ws.win, width, #list) end
  return true
end

--- Creates a workspace for every line that names none yet, after asking, the
--- way 'mini.files' synchronizes. Then re-lists from jj.
H.synchronize = function()
  local ws = H.workspaces
  local known, kept, create = {}, {}, {}
  for _, name in ipairs(ws.names) do
    known[name] = true
  end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(ws.buf, 0, -1, false)) do
    local name = vim.trim(line)
    if known[name] then
      kept[name] = true
    elseif name ~= '' and not vim.tbl_contains(create, name) then
      create[#create + 1] = name
    end
  end

  local removed = vim.tbl_filter(function(n) return not kept[n] end, ws.names)
  if #removed > 0 then
    vim.notify(
      'explorer: removing workspaces is not supported; kept '
        .. table.concat(removed, ', '),
      vim.log.levels.WARN
    )
  end

  if #create > 0 then
    local lines = vim.tbl_map(function(n) return '  CREATE │ ' .. n end, create)
    local msg = ('Synchronize workspaces of %s?\n\n%s'):format(
      ws.project,
      table.concat(lines, '\n')
    )
    if vim.fn.confirm(msg, '&Yes\n&No', 1, 'Question') ~= 1 then return end
    for _, name in ipairs(create) do
      projects.add_workspace(ws.project, name)
    end
  end
  H.render_workspaces()
end

--- Changes the editor's directory to the workspace under the cursor. A line
--- that is not synced yet names no workspace, so it does nothing.
H.cd = function()
  local ws = H.workspaces
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.trim(vim.api.nvim_get_current_line())
  local project, path = ws.project, ws.paths[lnum]
  if line ~= ws.names[lnum] or not path then return end
  H.close()
  vim.schedule(function() projects.cd(project, path) end)
end

--- Opens the workspace pane right of the project pane, for the project under
--- the cursor.
H.open_workspaces = function()
  local name = H.projects.names[vim.api.nvim_win_get_cursor(0)[1]]
  if not name then return end
  H.close_workspaces()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'huey://workspaces/' .. name)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'hueyexplorer'
  H.workspaces = { buf = buf, project = name, names = {}, paths = {} }
  if not H.render_workspaces() then
    vim.api.nvim_buf_delete(buf, { force = true })
    H.workspaces = { names = {}, paths = {} }
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

  H.map(buf, '<CR>', H.cd, 'Change directory to workspace')
  H.map(buf, '=', H.synchronize, 'Synchronize workspaces')
  H.map(buf, 'h', H.back, 'Back to projects')
  H.map(buf, 'q', H.close, 'Close')
  -- grow with new lines, so they are not scrolled out of view
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = function()
      if not H.is_open(win) then return end
      local width = H.workspaces.width or 0
      for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        width = math.max(width, vim.fn.strdisplaywidth(l))
      end
      H.resize(win, width, vim.api.nvim_buf_line_count(buf))
    end,
  })
  H.close_on_leave(buf)
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
  vim.bo[buf].undolevels = -1
  vim.bo[buf].filetype = 'hueyexplorer'
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
  H.map(buf, 'l', H.open_workspaces, 'Workspaces')
  H.map(buf, 'q', H.close, 'Close')
  H.map(buf, '<Esc>', H.close, 'Close')
  H.close_on_leave(buf)
end

return Explorer
