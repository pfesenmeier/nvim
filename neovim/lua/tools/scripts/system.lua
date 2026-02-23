--- allow using shell features, e.g. pipes
--- @param cmd string e.g. "ls | to json"
local function system_with_shell(cmd)
  local shell_cmd = {}

  table.insert(shell_cmd, vim.o.shell)
  vim.list_extend(shell_cmd, vim.split(vim.o.shellcmdflag, " "))
  table.insert(shell_cmd, cmd)

  return vim.system(shell_cmd)
end

local ls = "ls | to json"
local output = system_with_shell(ls):wait()
local stdout = output.stdout

if not stdout then
  vim.print("Exit Code: " .. tostring(output.code))
  vim.print("Stderr: " .. tostring(output.stderr))
  return
end

local json = vim.json.decode(stdout)
vim.print(json)

for _, item in ipairs(json) do
  vim.print(item.name)
end

