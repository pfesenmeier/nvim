local HueyBuffer = {}

HueyBuffer.delete_buf_swaps = function()
  -- Guard the raw name: `:p` on an empty string yields the cwd, not ''.
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    vim.notify('No file for current buffer', vim.log.levels.WARN)
    return
  end
  local mangled = vim.fn.fnamemodify(name, ':p'):gsub('/', '%%')
  local removed = {}
  for dir in vim.gsplit(vim.o.directory, ',', { plain = true }) do
    dir = vim.fn.expand(dir):gsub('/+$', '')
    for _, path in
      ipairs(vim.fn.glob(dir .. '/' .. mangled .. '.s[a-w][a-z]', false, true))
    do
      if vim.fn.delete(path) == 0 then table.insert(removed, path) end
    end
  end
  vim.notify(('Deleted %d swap file(s)'):format(#removed))
end

-- from original minimax config
HueyBuffer.new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

-- custom with ft
-- nice for setting up scratch sql buffers
HueyBuffer.new_scratch_buffer_with_ft = function()
  local opts = { prompt = 'filetype: ', completion = 'filetype' }

  -- All of it inside the callback: `vim.ui.input` only promises to hand the
  -- answer to `on_confirm`, so reading it after the call breaks under any
  -- async `vim.ui.input` override.
  vim.ui.input(opts, function(input)
    if input == nil then return end

    if not vim.tbl_contains(vim.fn.getcompletion(input, 'filetype'), input) then
      return vim.notify('unknown ft: ' .. input, vim.log.levels.ERROR)
    end

    HueyBuffer.new_scratch_buffer()
    vim.bo.filetype = input
  end)
end

HueyBuffer.setup = function() _G.HueyBuffer = HueyBuffer end

return HueyBuffer
