local env = {}

env.home = vim.uv.os_homedir()
local sysname = vim.uv.os_uname().sysname:lower()
env.islinux = string.match(sysname, "linux") ~= nil
env.is_wsl_linux = env.islinux and vim.env.WSL_DISTRO_NAME ~= nil
env.iswindows = string.match(sysname, "windows") ~= nil

env.binDir = env.home .. (env.islinux and "/.local/bin" or "/AppData/Local")

---@deprecated use vim.fs.joinpath instead
---@param ... string
---@return string
function env.pathjoin(...)
  local sep = nil

  if env.islinux then
    sep = "/"
  else
    sep = "\\"
  end

  local result = ""
  for _, value in ipairs({ ... }) do
    if result == "" then
      result = result .. value
    else
      result = result .. sep .. value
    end
  end

  return result
end

env.workdir = vim.fs.joinpath(env.home, "Cabo", "sfmono")
env.monorepo = false
env.c_sharp = false
env.sql = false
env.rust = false

return env
