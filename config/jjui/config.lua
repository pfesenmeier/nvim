function EditFile()
  local file = context.file()
  if not file or file == "" then
    flash("no file under cursor")
    return
  end
  local server = os.getenv("NVIM")
  if not server or server == "" then
    flash({ text = "not running inside nvim ($NVIM unset)", error = true })
    return
  end
  -- exec_shell takes over the terminal and then prints "press enter to continue"
  -- for any command that exits in under 5s. jj_async runs in the background
  -- instead, and `jj util exec` is what lets it run something other than jj.
  -- Passing argv directly also keeps paths with spaces intact.
  jj_async("util", "exec", "--", "nvim", "--server", server, "--remote", file)
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
