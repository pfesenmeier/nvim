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
  dotnet = {
    cmds = {
      install = { "tool", "install", "--global" }
    }
  },
  winget = {
    cmds = {
      install = { "install", "--no-upgrade", "--accept-package-agreements" }
    }
  },
}

return M
