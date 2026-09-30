return {
  settings = {
    gopls = {
      -- Format with gofumpt's stricter rules instead of plain gofmt
      gofumpt = true,
      staticcheck = true,
      usePlaceholders = false,
      hints = {
        parameterNames = true,
        assignVariableTypes = true,
        compositeLiteralFields = true,
      },
    },
  },
}
