local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local temp_roots = {}

--- Builds a real directory tree, since `root_dir()` reads the filesystem.
--- A trailing '/' makes a directory, anything else an empty file.
--- @param paths string[] root-relative paths
--- @return string root
local new_tree = function(paths)
  local root = vim.fn.tempname()
  for _, path in ipairs(paths) do
    local full = root .. '/' .. path
    if path:sub(-1) == '/' then
      vim.fn.mkdir(full, 'p')
    else
      vim.fn.mkdir(vim.fs.dirname(full), 'p')
      vim.fn.writefile({}, full)
    end
  end
  table.insert(temp_roots, root)
  return root
end

local cleanup_temp_roots = function()
  for _, root in ipairs(temp_roots) do
    vim.fn.delete(root, 'rf')
  end
  temp_roots = {}
end

--- Loads the real 'after/lsp/' config in the child. It is not on 'runtimepath'
--- under 'scripts/minimal_init.lua', so the file is what gets tested, not a copy.
local load_config = function()
  child.lua([[
    _G.cfg = dofile('after/lsp/terraformls.lua')
    --- Root that would be sent to terraform-ls for a buffer named `path`.
    _G.root_of = function(path)
      local buf = vim.api.nvim_create_buf(true, false)
      if path ~= nil then vim.api.nvim_buf_set_name(buf, path) end
      local got
      _G.cfg.root_dir(buf, function(dir) got = dir end)
      vim.api.nvim_buf_delete(buf, { force = true })
      return got
    end
  ]])
end

--- @param path string? buffer name, nil for an unnamed buffer
--- @return string?
local root_of = function(path) return child.lua_get('_G.root_of(...)', { path }) end

local T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      load_config()
    end,
    post_case = cleanup_temp_roots,
    post_once = child.stop,
  },
})

T['root_dir()'] = new_set()

T['root_dir()']['roots at a lockfile, not the enclosing repo'] = function()
  local root = new_tree({ '.git/', 'iac/main.tf', 'iac/.terraform.lock.hcl' })
  eq(root_of(root .. '/iac/main.tf'), root .. '/iac')
end

T['root_dir()']['prefers the nearest marker'] = function()
  local root = new_tree({
    '.git/',
    'iac/.terraform.lock.hcl',
    'iac/envs/prod/main.tf',
    'iac/envs/prod/.terraform/',
  })
  eq(root_of(root .. '/iac/envs/prod/main.tf'), root .. '/iac/envs/prod')
end

T['root_dir()']['roots at terragrunt.hcl'] = function()
  local root = new_tree({ '.git/', 'iac/terragrunt.hcl', 'iac/main.tf' })
  eq(root_of(root .. '/iac/main.tf'), root .. '/iac')
end

-- The regression: a project only ever applied from CI has no marker at all,
-- and '.git' in nvim-lspconfig's defaults rooted it at the repo top.
T['root_dir()']['roots an unmarked project at the project, not the repo'] = function()
  local root = new_tree({ '.git/', 'README.md', 'apps/api/main.go', 'iac/main.tf' })
  eq(root_of(root .. '/iac/main.tf'), root .. '/iac')
end

T['root_dir()']['roots a nested module at its project'] = function()
  local root = new_tree({ '.git/', 'iac/main.tf', 'iac/modules/vpc/main.tf' })
  eq(root_of(root .. '/iac/modules/vpc/main.tf'), root .. '/iac')
end

T['root_dir()']['gives sibling projects separate roots'] = function()
  local root = new_tree({ '.git/', 'iac/prod/main.tf', 'iac/dev/main.tf' })
  eq(root_of(root .. '/iac/prod/main.tf'), root .. '/iac/prod')
  eq(root_of(root .. '/iac/dev/main.tf'), root .. '/iac/dev')
end

T['root_dir()']['roots at the repo when the repo is the project'] = function()
  local root = new_tree({ '.git/', 'main.tf', 'modules/vpc/main.tf' })
  eq(root_of(root .. '/modules/vpc/main.tf'), root)
end

T['root_dir()']['stops at a jj repo boundary'] = function()
  local root = new_tree({ '.jj/', 'iac/main.tf' })
  eq(root_of(root .. '/iac/main.tf'), root .. '/iac')
end

T['root_dir()']['handles .tfvars buffers'] = new_set({
  parametrize = { { 'terraform.tfvars' }, { 'main.tf' } },
}, {
  test = function(name)
    local root = new_tree({ '.git/', 'iac/main.tf', 'iac/terraform.tfvars' })
    eq(root_of(root .. '/iac/' .. name), root .. '/iac')
  end,
})

T['root_dir()']['falls back to the buffer directory outside a repo'] = function()
  local root = new_tree({ 'loose/main.tf' })
  eq(root_of(root .. '/loose/main.tf'), root .. '/loose')
end

T['root_dir()']['falls back to cwd for an unnamed buffer'] = function()
  local root = new_tree({ 'iac/main.tf' })
  child.fn.chdir(root .. '/iac')
  eq(root_of(nil), root .. '/iac')
end

return T
