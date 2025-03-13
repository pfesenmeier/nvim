local env = require('pfes.env')
local path = require('pfes.path')

return {
  {
    "arnarg/todotxt.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      todo_file = path.pathjoin(env.home, "todo.txt")
    }
  }
}
