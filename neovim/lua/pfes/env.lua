local env = {}

env.home = vim.uv.os_homedir()
local sysname = vim.uv.os_uname().sysname:lower()
env.islinux = string.match(sysname, "linux") ~= nil
env.is_wsl_linux = env.islinux and vim.env.WSL_DISTRO_NAME ~= nil
env.iswindows = string.match(sysname, "windows") ~= nil

env.binDir = env.home .. (env.islinux and "/.local/bin" or "/AppData/Local")
-- used for neovide frontend
env.workdir =  vim.fs.joinpath(env.home, "Code")
env.monorepo = true
env.c_sharp = true
-- see roslynator.nu
env.roslynator_dir = vim.env.ROSLYNATOR_DIR
-- see roslyn_lsp.nu
env.roslyn_lsp = vim.env.ROSLYN_LSP

-- false or node version e.g. 21.1.1 
env.node = false
env.sql = false
env.rust = false

return env
