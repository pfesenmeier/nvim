--- @param nodeVersion string
--- @return string
local function findVue(nodeVersion)
  -- too slow
  -- local output = vim.fn.system{ 'npm', 'list', '--global', '--depth', '0', '--parseable', 'typescript' }
  local subpath = "installation/lib/node_modules/@vue/language-server"
  if Config.env.islinux then
    return vim.fs.joinpath(vim.env.HOME, ".local/share/fnm/node-versions", nodeVersion, subpath)
  else
    return vim.fs.joinpath(vim.env.APPDATA, "fnm/node-versions", nodeVersion, subpath)
  end
end

local vue_language_server_path = findVue(Config.env.node)
local filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' }

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
