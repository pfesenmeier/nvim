local M = {}

M.setup = function()
  vim.api.nvim_create_user_command("Cabo", function()
    vim.cmd(":term frontend")
    vim.cmd(":term backend")
  end, { desc = "Start Cabo" })

  -- vim.api.nvim_create_user_command("Gql", function()
  --   vim.cmd(":term gql")
  --   vim.cmd(":LspRestart")
  -- end, { desc = "refresh gql" })
end


return M
