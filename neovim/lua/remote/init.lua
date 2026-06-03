-- Server side of the nvim <-> tool bridge. External callers invoke these via
-- `nvim --server $NVIM --remote-send ':Remote<X> args<CR>'`, typically through
-- the `nv` CLI binary or jjui's exec_shell.

local M = {}

function M.open(file)
  -- Hide the floatterm first so focus returns to the main window;
  -- otherwise `:edit` would replace the terminal buffer inside the float.
  pcall(function() require("floatterm").hide() end)
  vim.cmd("edit " .. vim.fn.fnameescape(file))
end

function M.quickfix(files)
  local entries = vim.tbl_map(function(f)
    return { filename = f, lnum = 1, col = 1 }
  end, files)
  vim.fn.setqflist(entries, "r")
  vim.cmd("copen")
  -- If a floatterm float is up, drop it so the qflist is the visible thing.
  pcall(function() require("floatterm").hide() end)
end

function M.setup()
  vim.api.nvim_create_user_command("RemoteOpen", function(o)
    M.open(o.args)
  end, { nargs = 1, complete = "file", desc = "Open file via remote" })

  vim.api.nvim_create_user_command("RemoteQuickfix", function(o)
    M.quickfix(o.fargs)
  end, { nargs = "+", complete = "file", desc = "Set qflist via remote" })
end

return M
