-- terraform-ls indexes a *root module*: the directory where `terraform init`
-- runs and providers get locked. nvim-lspconfig's defaults end the marker list
-- with '.git', so a terraform project nested in a monorepo roots at the repo
-- top, where the server finds no providers and no modules. Root at the project
-- instead, which also yields one server per project rather than one per repo.

-- Only ever present in a root module directory. Nearest ancestor wins, so an
-- initialized project roots exactly where it was initialized.
local module_markers = { '.terraform', '.terraform.lock.hcl', 'terragrunt.hcl' }

-- Repo boundary. The walk below never roots above it.
local repo_markers = { '.git', '.jj' }

local is_tf_file = function(name)
  return name:match('%.tf$') ~= nil or name:match('%.tfvars$') ~= nil
end

--- @param dir string
--- @return boolean
local has_tf_files = function(dir)
  for name, entry_type in vim.fs.dir(dir) do
    if entry_type ~= 'directory' and is_tf_file(name) then return true end
  end
  return false
end

--- Outermost directory holding '.tf' files, searching up to the repo root.
--- Used when no marker exists, which is the common case for a project that is
--- only ever applied from CI. 'iac/modules/vpc' resolves to 'iac', so a nested
--- module shares its project's server instead of starting one of its own.
--- @param dir string
--- @return string?
local outermost_tf_dir = function(dir)
  local found = has_tf_files(dir) and dir or nil

  -- Without a repo there is nothing to stop the walk before $HOME.
  local repo = vim.fs.root(dir, repo_markers)
  if repo == nil or dir == repo then return found end

  for parent in vim.fs.parents(dir) do
    if has_tf_files(parent) then found = parent end
    if parent == repo then break end
  end
  return found
end

return {
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    -- A scratch terraform buffer has no path to walk up from.
    if fname == '' then return on_dir(vim.fn.getcwd()) end

    local dir = vim.fs.normalize(vim.fs.dirname(fname))
    on_dir(vim.fs.root(fname, module_markers) or outermost_tf_dir(dir) or dir)
  end,
}
