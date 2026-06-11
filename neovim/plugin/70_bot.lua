require("bot").setup({
  get_terminal = function()
    local t = require("floatterm").state.terms.claude
    if t and vim.api.nvim_buf_is_valid(t.buf) then return t.buf end
  end,
  open_terminal = function()
    local ft = require("floatterm")
    ft.open("claude")
    local t = ft.state.terms.claude
    if t and vim.api.nvim_buf_is_valid(t.buf) then return t.buf end
  end,
})
