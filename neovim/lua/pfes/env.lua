local env = {}

env.home = vim.fn.expand("$HOME") or vim.fn.expand("$USERPROFILE")

-- if fails to expand, it's linux
env.islinux = vim.fn.expand("$USERPROFILE") == "$USERPROFILE"
env.is_wsl_linux = env.islinux and vim.fn.expand("$WSL_DISTRO_NAME") ~= "$WSL_DISTRO_NAME"
env.iswindows = not env.islinux

env.binDir = env.home .. (env.islinux and "/.local/bin" or "/AppData/Local")

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

env.workdir = env.pathjoin(env.home, "Cabo", "sfmono")
env.monorepo = true
env.c_sharp = false
env.sql = false
env.rust = false



return env
