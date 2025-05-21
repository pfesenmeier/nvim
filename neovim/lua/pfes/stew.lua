local default_config = {
  recipe_dir = vim.fs.joinpath(vim.env.HOME, "Code", "StewLang", "recipes")
}

local M = {}

function M.setup(config)
  M.config = config or default_config
end

M.previous = nil

function M.select_recipe()
  local recipes = {}

  if (M.previous) then
    table.insert(recipes, M.previous)
  end

  for name in vim.fs.dir(M.config.recipe_dir) do
    table.insert(recipes, name)
  end

  local function set_previous(r)
    if (r) then
      M.previous = r
    end
  end

  vim.ui.select(recipes, {}, set_previous)

  return vim.fs.abspath(vim.fs.joinpath(M.config.recipe_dir, M.previous))
end

M.setup()

return M
