--- allow using shell features, e.g. pipes
--- @param cmd string e.g. "ls | to json"
--- @param fmt? 'json' | 'table'
--- @param shell? boolean
--- @return table
local function shell(cmd, fmt, shell)
  local opts = {}
  opts.fmt = fmt or 'other'
  opts.shell = shell or true
  local shell_cmd = {}

  if opts.shell then
    table.insert(shell_cmd, vim.o.shell)
    vim.list_extend(shell_cmd, vim.split(vim.o.shellcmdflag, " "))
    table.insert(shell_cmd, cmd)
  else
    table.insert(vim.split(cmd, " "))
  end

  local outcome = vim.system(shell_cmd):wait()

  if outcome.code ~= 0 then
    print('err')
    return {}
  end

  local data = outcome.stdout

  if data == nil then
    return {}
  end

  if fmt == 'json' then
    return vim.json.decode(data)
  end

  if fmt == 'table' then
    return vim.split(outcome.stdout, '\n')
  end

  return {}
end

return {
  shell = shell
}
