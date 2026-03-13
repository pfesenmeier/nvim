local M = {}
local opts = { noremap = true, silent = true }

M.setup = function()
  vim.keymap.set("n", "<leader>jd", function()
    local result = vim.system({ "jj", "diff", "--name-only" }):wait()
    if result.code ~= 0 then
      vim.notify("jj diff failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
      return
    end
    local items = {}
    for line in result.stdout:gmatch("[^\r\n]+") do
      table.insert(items, { filename = line })
    end
    vim.fn.setqflist(items)
    vim.cmd("copen")
  end, opts)

  vim.keymap.set("n", "<leader>jD", function()
    local result = vim.system({ "jj", "diff", "--from", "main", "--name-only" }):wait()
    if result.code ~= 0 then
      vim.notify("jj diff failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
      return
    end
    local items = {}
    for line in result.stdout:gmatch("[^\r\n]+") do
      table.insert(items, { filename = line })
    end
    vim.fn.setqflist(items)
    vim.cmd("copen")
  end, opts)
end

return M
