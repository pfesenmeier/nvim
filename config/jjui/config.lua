function EditFile()
  local file = context.file()
  if not file or file == "" then
    flash("no file under cursor")
    return
  end
  -- exec_shell inherits env, so the spawned shell sees $NVIM and runs `nv`.
  exec_shell("nvim --server $NVIM --remote " .. file)
  flash("→ " .. file)
end

function CopyFocusedFile()
  local file = context.file()
  if not file or file == "" then
    flash("no file under cursor")
    return
  end
  local ok, err = copy_to_clipboard(file)
  if ok then
    flash("⎘ " .. file)
  else
    flash({ text = "copy failed: " .. (err or "?"), error = true })
  end
end

function CopyCheckedFiles()
  local files = context.checked_files()
  if #files == 0 then
    flash("nothing checked")
    return
  end
  local ok, err = copy_to_clipboard(table.concat(files, "\n"))
  if ok then
    flash("⎘ " .. #files .. " files")
  else
    flash({ text = "copy failed: " .. (err or "?"), error = true })
  end
end
