local HueyTerm = {}

---@param cmd string
HueyTerm.term_with_buf_num = function(cmd)
  vim.cmd.enew()
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = {
    term = true,
    env = {
      NVIM_BUFNR = bufnr
    }
  }
  local chanid = vim.fn.jobstart(cmd, opts)

  return chanid, bufnr
end

HueyTerm.setup = function()
 _G.HueyTerm = HueyTerm
end

return HueyTerm
