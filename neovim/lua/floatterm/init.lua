-- Floating-terminal plugin.
-- One float window at a time, swapping between named terminal buffers that
-- persist across hides (hidden from the buffer list).

local M = {}

local state = {
  win = -1,
  current = nil,    -- name of terminal currently visible
  last = nil,       -- name of most-recently-shown terminal (for open_last)
  terms = {},       -- name -> { buf, cmd }
}

local defaults = {
  terminals = {},
  keymap_prefix = "<leader>t",
  hide_key = [[<C-\><C-\>]],
  last_key = [[<C-\>]],
  resume_key = "r",  -- under keymap_prefix; <leader>tr reopens last terminal
  window = { width = 0.9, height = 0.9, border = "rounded" },
}

local opts = defaults

local function geometry()
  local w = math.floor(vim.o.columns * opts.window.width)
  local h = math.floor(vim.o.lines * opts.window.height)
  return {
    relative = "editor",
    row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2),
    width = w,
    height = h,
    border = opts.window.border,
  }
end

local function hide_internal()
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_hide(state.win)
  end
  state.win = -1
  state.current = nil
end

function M.hide()
  hide_internal()
end

function M.open(name)
  local cfg = opts.terminals[name]
  if not cfg then return end

  -- Toggle: same terminal already visible → hide.
  if state.current == name and vim.api.nvim_win_is_valid(state.win) then
    hide_internal()
    return
  end

  -- Only one float at a time.
  if vim.api.nvim_win_is_valid(state.win) then
    hide_internal()
  end

  local t = state.terms[name]

  if t and vim.api.nvim_buf_is_valid(t.buf) then
    state.win = vim.api.nvim_open_win(t.buf, true, geometry())
  else
    -- First use: open the float on a scratch buffer, then convert to terminal.
    -- `:terminal` creates a new buffer in the current window; capture it.
    local placeholder = vim.api.nvim_create_buf(false, true)
    state.win = vim.api.nvim_open_win(placeholder, true, geometry())

    if cfg.cmd then
      vim.cmd("terminal " .. cfg.cmd)
    else
      vim.cmd("terminal")
    end

    local term_buf = vim.api.nvim_win_get_buf(state.win)
    vim.bo[term_buf].buflisted = false
    vim.bo[term_buf].bufhidden = "hide"
    state.terms[name] = { buf = term_buf, cmd = cfg.cmd }

    if vim.api.nvim_buf_is_valid(placeholder) and placeholder ~= term_buf then
      pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
    end
  end

  vim.cmd("startinsert")
  state.current = name
  state.last = name
end

function M.open_last()
  if state.last then
    M.open(state.last)
  end
end

local function deep_merge(default, override)
  local result = vim.deepcopy(default)
  for k, v in pairs(override or {}) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

function M.setup(user_opts)
  opts = deep_merge(defaults, user_opts or {})

  for name, cfg in pairs(opts.terminals) do
    if cfg.key then
      vim.keymap.set("n", opts.keymap_prefix .. cfg.key, function()
        M.open(name)
      end, { desc = "Float: " .. name })
    end
  end

  vim.keymap.set("t", opts.hide_key, function() M.hide() end, {
    desc = "Float: hide",
  })

  vim.keymap.set({ "n", "i" }, opts.last_key, function() M.open_last() end, {
    desc = "Float: reopen last",
  })

  if opts.resume_key then
    vim.keymap.set("n", opts.keymap_prefix .. opts.resume_key, function()
      M.open_last()
    end, { desc = "Float: resume last" })
  end

  -- mini.clue integration: push explicit clue entries so the popup shows the
  -- terminal name (mini.clue would otherwise just use the keymap desc, which
  -- works too — this is belt-and-suspenders).
  local ok, miniclue = pcall(require, "mini.clue")
  if ok and miniclue.config and miniclue.config.clues then
    local clue_prefix = opts.keymap_prefix:gsub("<[Ll]eader>", "<Leader>")
    for name, cfg in pairs(opts.terminals) do
      if cfg.key then
        table.insert(miniclue.config.clues, {
          mode = "n",
          keys = clue_prefix .. cfg.key,
          desc = "Float: " .. name,
        })
      end
    end
    if opts.resume_key then
      table.insert(miniclue.config.clues, {
        mode = "n",
        keys = clue_prefix .. opts.resume_key,
        desc = "Float: resume last",
      })
    end
  end
end

-- Exposed for tests / debugging.
M.state = state

return M
