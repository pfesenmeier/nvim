#!/usr/env -S nvim -l

---@param state number
---@param value number?
local send_progress = function(state, value)
  io.write(string.format("\27]9;4;%d;%d\7", state, value or 0))
  io.stdout:flush()
end


---@param ... string
---@return vim.SystemCompleted
local run_cmd = function(...)
  local shell = vim.o.shell
  local shellcmdflag = vim.split(vim.o.shellcmdflag, "%s+", { trimempty = true })
  local cmd = vim.iter({
    shell,
    shellcmdflag,
    ...
  }):flatten():totable()

  return vim.system(cmd):wait()
end

if #arg == 0 then return end

send_progress(1, 25)
-- remove non-positive entries
local cmd = table.unpack(arg)
local completed =  run_cmd(cmd)
if completed.code == 0 then
  send_progress(1, 100)
else
  send_progress(2)
end
