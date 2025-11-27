local M = {}

M.package_managers = {
  npm = {
    cmds = {
      install = { "install", "-g" }
    }
  },
  brew = {
    cmds = {
      install = { "install", "--quiet" }
    }
  },
  scoop = {},
  winget = {
    cmds = {
      install = { "install", "--no-upgrade", "--accept-package-agreements" }
    }
  },
}

return M
