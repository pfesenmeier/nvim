local packages = require("pfes/packages")

local function headless_paq()
  -- Set to exit nvim after installing plugins
  local paq = require("paq")
  vim.cmd("autocmd User PaqDoneInstall quit")
  paq(packages)
  paq.install()
end

return {
  headless_paq = headless_paq,
}
