local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local make_entry = require "telescope.make_entry"
local sorters = require("telescope.sorters")
local env = require "pfes.env"

local M = {}

-- from https://github.com/tjdevries/advent-of-nvim/blob/master/nvim/lua/config/telescope/multigrep.lua
function M.globbed_grep_picker(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = finders.new_async_job {
    command_generator = function(prompt)
      if not prompt or prompt == "" then
        return nil
      end

      local pieces = vim.split(prompt, "  ")
      local args = { "rg" }
      if pieces[1] then
        table.insert(args, "-e")
        table.insert(args, pieces[1])
      end

      if pieces[2] then
        table.insert(args, "-g")
        table.insert(args, pieces[2])
      end

      return vim.iter({ args, {
            "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" } }):flatten()
          :totable()
    end,
    entry_maker = make_entry.gen_from_vimgrep(opts),
    cwd = opts.cwd
  }

  pickers.new(opts, {
    debounce = 100,
    prompt_title = "Globbed Grep",
    finder = finder,
    previewer = conf.grep_previewer(opts),
    sorter = sorters.empty()
  }):find()
end

function M.setup()
  vim.keymap.set("n", "<leader><leader>k", M.globbed_grep_picker)
  vim.keymap.set("n", "<leader><leader>K", function()
    M.globbed_grep_picker({
      cwd = env.home
    })
  end)
end

return M
