-- - `MiniFilesActionRename` - after entry is successfully renamed.
--
-- - `MiniFilesActionCopy` - after entry is successfully copied.
--
-- - `MiniFilesActionMove` - after entry is successfully moved.
--
-- Callback for each file action event will receive `data` field
-- (see |nvim_create_autocmd()|) with the following information:
--
-- - <action> - string with action name.
-- - <from> - full path of entry before action (`nil` for "create" action).
-- - <to> - full path of entry after action (`nil` for permanent "delete" action).
--

local group = vim.api.nvim_create_augroup("RenameFiles", { clear = true })

vim.api.nvim_create_autocmd({ "User" }, {
  pattern = { "MiniFilesActionRename", "MiniFilesActionMove" },
  group = group,
  callback = function(event)
    local clients = vim.lsp.get_clients()

    for _, client in ipairs(clients) do
      -- local did_send = client:notify("workspace/didRenameFiles", {
      --   to = event.data.to,
      --   from = event.data.from
      -- })

      -- if not did_send then
      --   print("notification did not send")
      -- end
    end
    -- call lsp to find all references? or simple regex? lsp would understand path alias, stuff
  end,
})
