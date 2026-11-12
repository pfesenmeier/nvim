local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local eq = helpers.expect.equality
local new_set = MiniTest.new_set

local project_names = { 'alpha', 'beta', 'gamma' }

local temp_roots = {}

--- Loads the explorer in the child over a store listing `project_names`, with
--- `status` stubbed (no sockets probed) and `connect` recording its target.
--- @param running table<string, boolean> which projects report 'running'
--- @param cwd string? project to chdir into first
local setup = function(running, cwd)
  local root = vim.fn.tempname()
  table.insert(temp_roots, root)
  local spec = {}
  for _, name in ipairs(project_names) do
    vim.fn.mkdir(root .. '/' .. name, 'p')
    spec[#spec + 1] = { name = name, path = root .. '/' .. name }
  end
  vim.fn.writefile({ vim.json.encode(spec) }, root .. '/projects.json')

  child.lua(
    [[
    local o, running = ...
    local projects = require('huey.projects')
    projects.setup(o)
    projects.status = function(name) return running[name] and 'running' or 'stopped' end
    _G.connected = {}
    projects.connect = function(name) table.insert(_G.connected, name) end
    _G.explorer = require('huey.explorer')
  ]],
    {
      { store = root .. '/projects.json', pinned = {}, server_dir = root .. '/servers' },
      running,
    }
  )
  if cwd then child.fn.chdir(root .. '/' .. cwd) end
end

local open = function() child.lua('_G.explorer.open()') end
local is_float = function() return child.api.nvim_win_get_config(0).relative ~= '' end
local cursor_line = function() return child.api.nvim_win_get_cursor(0)[1] end

--- Presses `keys`, then lets `vim.schedule` callbacks run.
local press = function(keys)
  child.type_keys(keys)
  child.poke_eventloop()
end

local T = new_set({
  hooks = {
    pre_case = child.setup,
    post_case = function()
      for _, root in ipairs(temp_roots) do
        vim.fn.delete(root, 'rf')
      end
      temp_roots = {}
    end,
    post_once = child.stop,
  },
})

T['open()'] = new_set()

T['open()']['lists projects in a focused float'] = function()
  setup({})
  open()
  eq(is_float(), true)
  eq(child.get_lines(), project_names)
  eq(child.bo.modifiable, false)
end

T['open()']['starts on the current project'] = function()
  setup({}, 'gamma')
  open()
  eq(cursor_line(), 3)
end

T['open()']['starts on the first project outside any project'] = function()
  setup({})
  open()
  eq(cursor_line(), 1)
end

T['open()']['marks running projects'] = function()
  setup({ beta = true })
  open()
  local glyphs = child.lua_get([[vim.tbl_map(function(m)
    return m[4].virt_text[1][1]
  end, vim.tbl_filter(function(m)
    return m[4].virt_text_pos == 'inline'
  end, vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })))]])
  eq(glyphs, { '○ ', '● ', '○ ' })
end

T['open()']['focuses the pane when already open'] = function()
  setup({})
  open()
  local win = child.api.nvim_get_current_win()
  open()
  eq(#child.api.nvim_list_wins(), 2)
  eq(child.api.nvim_get_current_win(), win)
end

T['keys'] = new_set()

T['keys']['<CR> connects to the project under the cursor'] = function()
  setup({})
  open()
  press('j<CR>')
  eq(child.lua_get('_G.connected'), { 'beta' })
  eq(is_float(), false)
end

T['keys']['l connects too'] = function()
  setup({})
  open()
  press('jjl')
  eq(child.lua_get('_G.connected'), { 'gamma' })
end

T['keys']['<CR> on the current project only closes'] = function()
  setup({}, 'beta')
  open()
  press('<CR>')
  eq(child.lua_get('_G.connected'), {})
  eq(is_float(), false)
end

T['keys']['q and <Esc> close'] = function()
  setup({})
  open()
  press('q')
  eq(is_float(), false)
  open()
  press('<Esc>')
  eq(is_float(), false)
  eq(child.lua_get('_G.connected'), {})
end

T['keys']['leaving the pane closes it'] = function()
  setup({})
  open()
  child.cmd('wincmd p')
  child.poke_eventloop()
  eq(#child.api.nvim_list_wins(), 1)
end

return T
