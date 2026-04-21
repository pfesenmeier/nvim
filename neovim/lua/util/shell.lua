--- allow using shell features, e.g. pipes
--- @param cmd string e.g. "ls | to json"
--- @param fmt? 'json' | 'table' | 'str'
--- @param use_shell? boolean
--- @return table | string
local function shell(cmd, fmt, use_shell)
  local opts = {}
  opts.fmt = fmt or 'string'
  opts.shell = use_shell or true
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
    vim.notify('shell err')
    vim.notify(outcome.stderr)
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
    return vim.split(data, '\n')
  end

  return data
end

return {
  shell = shell
}
