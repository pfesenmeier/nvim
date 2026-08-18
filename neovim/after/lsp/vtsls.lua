--- @return string
local function findVue()
  -- too slow
  -- local output = vim.fn.system{ 'npm', 'list', '--global', '--depth', '0', '--parseable', 'typescript' }
  -- pnpm keys global installs by content hash, not node/package version, so glob for it
  local pattern = vim.fs.joinpath(
    vim.env.PNPM_HOME,
    'global',
    '*',
    '*',
    'node_modules',
    '@vue',
    'language-server'
  )
  return vim.fn.glob(pattern, false, true)[1]
end

local vue_language_server_path = findVue()
local filetypes =
  { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' }

local vue_plugin = {
  name = '@vue/typescript-plugin',
  location = vue_language_server_path,
  languages = { 'vue' },
  configNamespace = 'typescript',
}
return {
  settings = {
    vtsls = {
      autoUseWorkspaceTsdk = true,
      tsserver = {
        globalPlugins = {
          vue_plugin,
        },
      },
    },
  },
  filetypes = filetypes,
}
