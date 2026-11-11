-- Machine-specific settings. Not checked in (see .gitignore).

local join = vim.fs.joinpath
local home = vim.uv.os_homedir()
local code = join(home, 'Code')

-- Workspaces: every folder in ~/Code, plus ~/nvim and ~/Todo
local workspaces = {}
for name, type in vim.fs.dir(code) do
  if type == 'directory' then table.insert(workspaces, { name = name, path = join(code, name) }) end
end
table.sort(workspaces, function(a, b) return a.name < b.name end)
table.insert(workspaces, { name = 'nvim', path = join(home, 'nvim') })
table.insert(workspaces, { name = 'Todo', path = join(home, 'Todo') })

return {
  workspaces = workspaces,
}
