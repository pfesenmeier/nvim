local default_config = {
  recipe_dir = vim.fs.joinpath(vim.uv.os_homedir(), "Code", "StewLang", "recipes"),
  cli_path = vim.fs.joinpath(vim.uv.os_homedir(), "Code", "StewLang", "cli", "main.ts")
}

local M = {}

function M.setup(config)
  M.config = config or default_config

  vim.keymap.set('n', '<leader><leader>s', M.parse_recipe)
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

local function read_text()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  local text = vim.iter(lines):fold("", function(acc, v)
    if acc == "" and v ~= "" then
      return acc .. v
    end
    return acc .. "\n" .. v
  end)

  return text
end

function M.parse_recipe()
  local current_file = vim.api.nvim_buf_get_name(0)

  local function on_exit(obj)
    print(obj.stdout)
    print(obj.stderr)
  end

  vim.system({ "deno", "run", M.config.cli_path, current_file}, { text = true }, on_exit)
end

M.setup()

return M
