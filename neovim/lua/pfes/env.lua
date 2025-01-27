local env = {}

env.home = vim.fn.expand("$HOME") or vim.fn.expand("USERPROFILE")

-- if fails to expand, it's linux
env.islinux = vim.fn.expand("$USERPROFILE") == "$USERPROFILE"

env.binDir = env.home .. (env.islinux and "/.local/bin" or "/AppData/Local")

env.c_sharp = false
env.sql = false

return env
