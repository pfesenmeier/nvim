local brew_tools = require('tools.specs.brew_tools')
local lang_servers = require('tools.specs.lang_servers')

local all =  vim.list_extend(brew_tools, lang_servers)

return all
