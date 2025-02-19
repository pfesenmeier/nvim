local env = require('pfes.env')

vim.api.nvim_create_autocmd({ 'TermRequest' }, {
  desc = 'Handles OSC 7 dir change requests',
  callback = function(ev)
    if string.sub(vim.v.termrequest, 1, 4) == '\x1b]7;' then
      local dir = string.gsub(vim.v.termrequest, '\x1b]7;file://[^/]*', '')

      if not env.islinux then
        -- cleans up string such as '/C:\Users\foobar'
        dir = string.sub(dir, 2)
      end

      if vim.fn.isdirectory(dir) == 0 then
        vim.notify('invalid dir: ' .. dir)
        return
      end
      vim.api.nvim_buf_set_var(ev.buf, 'osc7_dir', dir)
      if vim.o.autochdir and vim.api.nvim_get_current_buf() == ev.buf then
        vim.cmd.cd(dir)
      end
    end
  end
})
vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'DirChanged' }, {
  callback = function(ev)
    if vim.b.osc7_dir and vim.fn.isdirectory(vim.b.osc7_dir) == 1 then
      vim.cmd.cd(vim.b.osc7_dir)
    end
  end
})
-- for debugging
-- vim.opt.cmdheight = 0
