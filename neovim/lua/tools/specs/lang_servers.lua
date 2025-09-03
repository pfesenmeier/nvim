-- TODO move to brew_tools, rename to main or something
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
  "@vtsls/language-server",
  "@prisma/language-server",
  "prettier", -- install globally
  "vscode-langservers-extracted",   -- css, eslint, html
  "@tailwindcss/language-server",
  "@anthropic-ai/claude-code",
  "@zed-industries/claude-code-acp"
}

local specs = {}

for _, value in ipairs(tools) do
  table.insert(specs, npm_tool(value))
end

return specs
