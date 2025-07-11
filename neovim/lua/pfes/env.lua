local env = {}

env.home = vim.uv.os_homedir()
local sysname = vim.uv.os_uname().sysname:lower()
env.islinux = string.match(sysname, "linux") ~= nil
env.is_wsl_linux = env.islinux and vim.env.WSL_DISTRO_NAME ~= nil
env.iswindows = string.match(sysname, "windows") ~= nil

env.binDir = env.home .. (env.islinux and "/.local/bin" or "/AppData/Local")
env.workdir = vim.fs.joinpath(env.home, "Cabo", "sfmono")
env.monorepo = false
env.c_sharp = false
env.node = true
env.sql = false
env.rust = false

return env
