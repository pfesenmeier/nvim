-- dadbod
vim.b.db = "postgres://postgres:postgres@0.0.0.0:5432/db"

-- dadbod-completion
-- Re-assert after LspAttach: buffer-local fires first (before global), so
-- vim.schedule defers past mini.completion's global handler that overrides omnifunc.
local function set_omnifunc() vim.bo.omnifunc = "vim_dadbod_completion#omni" end
set_omnifunc()
vim.api.nvim_create_autocmd("LspAttach", {
  buffer = 0,
  callback = function() vim.schedule(set_omnifunc) end,
})

-- Auto-trigger omnifunc on typing, like mini.completion does for LSP buffers.
-- mini only auto-triggers <C-x><C-o> when an LSP is attached; dadbod isn't an LSP.
-- Buffer-local autocmds fire before global ones, so our timer starts slightly
-- earlier — if dadbod opens a pum, mini's keyword fallback sees pumvisible()=1
-- and backs off. If dadbod returns nothing, mini's keyword fallback still runs.
local timer = (vim.uv or vim.loop).new_timer()
vim.api.nvim_create_autocmd("TextChangedI", {
  buffer = 0,
  callback = function()
    timer:stop()
    timer:start(100, 0, vim.schedule_wrap(function()
      if vim.fn.mode() ~= "i" or vim.fn.pumvisible() == 1 then return end
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n", false
      )
    end))
  end,
})
vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
  buffer = 0,
  callback = function() timer:stop() end,
})
