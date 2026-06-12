require("bot").setup({
  get_terminal = function()
    local ft = require("floatterm")
    local t = ft.state.terms.claude
    if not (t and vim.api.nvim_buf_is_valid(t.buf)) then return end
    -- Only treat as "open" when the float is actually visible. Otherwise fall
    -- through to open_terminal so sending pops the float into view.
    if ft.state.current == "claude" and vim.api.nvim_win_is_valid(ft.state.win) then
      return t.buf
    end
  end,
  open_terminal = function()
    local ft = require("floatterm")
    ft.open("claude")
    local t = ft.state.terms.claude
    if t and vim.api.nvim_buf_is_valid(t.buf) then return t.buf end
  end,
})
