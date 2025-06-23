local function npm_tool(exe)
  return {
    name = exe,
    src = {
      "npm"
    }
  }
end

local tools = {
  "dockerfile-language-server-nodejs",
  "graphql-language-service-cli",
  "typescript",
  "typescript-language-server",
  "@vue/language-server",
  "@prisma/language-server",
  "vscode-langservers-extracted",   -- css, eslint, html
  "@tailwindcss/language-server",
}

local specs = {}

for _, value in ipairs(tools) do
  table.insert(specs, npm_tool(value))
end

return specs
