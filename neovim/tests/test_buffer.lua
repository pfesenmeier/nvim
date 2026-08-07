local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local expect = helpers.expect
local new_set = MiniTest.new_set

local temp_roots = {}

local new_temp_dir = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  table.insert(temp_roots, root)
  return root
end

local cleanup_temp_roots = function()
  for _, root in ipairs(temp_roots) do
    vim.fn.delete(root, 'rf')
  end
  temp_roots = {}
end

--- Loads the module in the child with `vim.ui.input` answering `answer`
--- immediately and `vim.notify` recording into `_G.notified`.
--- @param answer string? value handed to the prompt callback (nil = cancelled)
local setup_buf = function(answer)
  child.lua(
    [[
    -- `plugin/` is not on the child's 'runtimepath', so `_G.HueyBuffer` (set by
    -- 'plugin/50_libraries.lua') does not exist here. Require the module.
    local answer = ...
    _G.buf = require('huey.buffer')

    _G.notified = {}
    vim.notify = function(msg, level) table.insert(_G.notified, { msg = msg, level = level }) end

    _G.input_opts = nil
    vim.ui.input = function(opts, on_confirm)
      _G.input_opts = opts
      on_confirm(answer)
    end
  ]],
    -- a nil `answer` yields an empty argument list, so `...` is nil: the
    -- cancelled case needs no separate stub
    { answer }
  )
end

local n_bufs = function() return child.lua_get('#vim.api.nvim_list_bufs()') end
local cur_buf = function() return child.lua_get('vim.api.nvim_get_current_buf()') end
local notified = function() return child.lua_get('_G.notified') end

local T = new_set({
  hooks = {
    pre_case = child.setup,
    post_case = cleanup_temp_roots,
    post_once = child.stop,
  },
})

T['new_scratch_buffer()'] = new_set()

T['new_scratch_buffer()']['puts a scratch buffer in the current window'] = function()
  setup_buf()
  local before = cur_buf()

  child.lua('_G.buf.new_scratch_buffer()')

  expect.no_equality(cur_buf(), before)
  -- the `nvim_create_buf(true, true)` contract
  eq(child.bo.buftype, 'nofile')
  eq(child.bo.swapfile, false)
  eq(child.fn.buflisted(0), 1)
end

T['new_scratch_buffer_with_ft()'] = new_set()

T['new_scratch_buffer_with_ft()']['sets the filetype on a valid input'] = function()
  setup_buf('sql')
  local before = cur_buf()

  child.lua('_G.buf.new_scratch_buffer_with_ft()')

  expect.no_equality(cur_buf(), before)
  eq(child.bo.filetype, 'sql')
  eq(child.bo.buftype, 'nofile')
  eq(notified(), {})
end

T['new_scratch_buffer_with_ft()']['prompts with filetype completion'] = function()
  setup_buf('sql')

  child.lua('_G.buf.new_scratch_buffer_with_ft()')

  eq(child.lua_get('_G.input_opts.completion'), 'filetype')
end

T['new_scratch_buffer_with_ft()']['creates no buffer on an unknown filetype'] = function()
  setup_buf('zzz')
  local before, n_before = cur_buf(), n_bufs()

  child.lua('_G.buf.new_scratch_buffer_with_ft()')

  eq(cur_buf(), before)
  eq(n_bufs(), n_before)
  eq(#notified(), 1)
  expect.match(notified()[1].msg, 'unknown ft')
  eq(notified()[1].level, child.lua_get('vim.log.levels.ERROR'))
end

T['new_scratch_buffer_with_ft()']['creates no buffer on empty input'] = function()
  setup_buf('')
  local before, n_before = cur_buf(), n_bufs()

  child.lua('_G.buf.new_scratch_buffer_with_ft()')

  eq(cur_buf(), before)
  eq(n_bufs(), n_before)
  eq(#notified(), 1)
end

T['new_scratch_buffer_with_ft()']['is a silent no-op when cancelled'] = function()
  setup_buf()
  local before, n_before = cur_buf(), n_bufs()

  child.lua('_G.buf.new_scratch_buffer_with_ft()')

  eq(cur_buf(), before)
  eq(n_bufs(), n_before)
  eq(notified(), {})
end

T['delete_buf_swaps()'] = new_set()

T['delete_buf_swaps()']['warns for an unnamed buffer'] = function()
  setup_buf()

  child.lua('_G.buf.delete_buf_swaps()')

  eq(#notified(), 1)
  expect.match(notified()[1].msg, 'No file for current buffer')
  eq(notified()[1].level, child.lua_get('vim.log.levels.WARN'))
end

T['delete_buf_swaps()']['deletes swaps for the current file'] = function()
  local swap_dir = new_temp_dir()
  local path = new_temp_dir() .. '/f.txt'

  -- Written by hand rather than provoked out of nvim: an `:edit` of a file that
  -- already has a swap raises E325, which would block the headless child.
  local mangled = swap_dir .. '/' .. path:gsub('/', '%%')
  local swaps = { mangled .. '.swp', mangled .. '.swo' }
  for _, swap in ipairs(swaps) do
    vim.fn.writefile({ '' }, swap)
  end

  setup_buf()
  child.o.directory = swap_dir
  -- names the buffer without loading the file, so nvim adds no swap of its own
  child.api.nvim_buf_set_name(0, path)

  child.lua('_G.buf.delete_buf_swaps()')

  for _, swap in ipairs(swaps) do
    eq(vim.fn.filereadable(swap), 0)
  end
  eq(#notified(), 1)
  expect.match(notified()[1].msg, 'Deleted 2 swap file%(s%)')
end

return T
