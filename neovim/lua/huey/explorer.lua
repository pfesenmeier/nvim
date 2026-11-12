-- Huey explorer: floating panes for moving between projects, a la 'mini.files'.
-- For now there is one pane, the project list. `<CR>` or `l` connects the UI
-- to the project under the cursor; see 'lua/huey/projects'.
local projects = require('huey.projects')

local Explorer = {}
local H = {}

H.ns = vim.api.nvim_create_namespace('HueyExplorer')

--- @type integer?
local win
--- Project name on each buffer line
--- @type string[]
local names = {}

H.close = function()
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  win, names = nil, {}
end

--- Connects to the project under the cursor. The pane closes first, so it is
--- not still open when the UI comes back to this server.
H.choose = function()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local name = names[lnum]
  H.close()
  -- already here; `:connect` to our own server would go nowhere
  if not name or lnum == projects.current_index() then return end
  vim.schedule(function() projects.connect(name) end)
end

--- @param buf integer
--- @return integer width widest line, glyph and path included
H.render = function(buf)
  names = projects.names()
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
      virt_text = { { running and '● ' or '○ ', running and 'DiagnosticOk' or 'Comment' } },
      virt_text_pos = 'inline',
    })
    vim.api.nvim_buf_set_extmark(buf, H.ns, i - 1, 0, {
      end_col = #name,
      hl_group = i == current and 'Title' or nil,
      virt_text = { { '  ' .. path, 'Comment' } },
      virt_text_pos = 'eol',
    })
    width = math.max(width, 2 + vim.fn.strdisplaywidth(name) + 2 + vim.fn.strdisplaywidth(path))
  end
  return width
end

--- Opens the project pane in the top left corner, with the cursor on the
--- current project. Focuses it when it is already open.
Explorer.open = function()
  if win and vim.api.nvim_win_is_valid(win) then return vim.api.nvim_set_current_win(win) end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'huey://projects')
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].undolevels = -1
  vim.bo[buf].filetype = 'hueyexplorer'
  local width = H.render(buf)

  win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = 1,
    col = 0,
    width = math.max(math.min(width + 1, vim.o.columns - 4), 20),
    height = math.max(math.min(#names, vim.o.lines - 6), 1),
  })
  vim.wo[win][0].wrap = false
  vim.wo[win][0].number = false
  vim.wo[win][0].relativenumber = false
  vim.wo[win][0].signcolumn = 'no'
  vim.wo[win][0].cursorline = true
  vim.api.nvim_win_set_cursor(win, { math.min(projects.current_index() or 1, math.max(#names, 1)), 0 })

  local map = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = buf, nowait = true, desc = desc })
  end
  map('<CR>', H.choose, 'Connect to project')
  map('l', H.choose, 'Connect to project')
  map('q', H.close, 'Close')
  map('<Esc>', H.close, 'Close')

  -- a float left behind would sit over whatever window took focus
  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = buf,
    once = true,
    desc = 'Close the project pane',
    callback = function() vim.schedule(H.close) end,
  })
end

return Explorer
