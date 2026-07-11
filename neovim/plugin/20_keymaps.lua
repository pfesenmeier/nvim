-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- An example helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')

-- Quickfix list stack navigation (mini.bracketed-style: lowercase=step, uppercase=end)
nmap('[e', function() require('quickfix').list_goto('prev')  end, 'Older qf list')
nmap(']e', function() require('quickfix').list_goto('next')  end, 'Newer qf list')
nmap('[E', function() require('quickfix').list_goto('first') end, 'Oldest qf list')
nmap(']E', function() require('quickfix').list_goto('last')  end, 'Newest qf list')

-- Quickfix add (operator/visual) and new list. See `lua/quickfix/init.lua`.
-- - `gca<motion>` add motion range as a single qf entry (e.g. `gca_` for current line)
-- - `gca`        in visual mode adds the selection
-- - `gcn`        push a new (empty) qf list with a prompted title
vim.keymap.set('n', 'gca', function() return require('quickfix').operator() end,
  { expr = true, desc = 'QF add (operator)' })
vim.keymap.set('x', 'gca', function() require('quickfix').visual() end,
  { desc = 'QF add selection' })
vim.keymap.set('n', 'gcn', function() require('quickfix').new_list() end,
  { desc = 'QF new list' })

-- Pretty-yank a buffer range to a register without going through quickfix.
-- Uses `share`'s "location" formatter. e.g. `gY_`, `gYj`, `gYap`, visual `gY`.
vim.keymap.set('n', 'gY', function() return require('share').buffer_operator() end,
  { expr = true, desc = 'Pretty yank (operator)' })
vim.keymap.set('x', 'gY', function() require('share').buffer_visual() end,
  { desc = 'Pretty yank selection' })

-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
-- Use this section to add Leader mappings in a structural manner.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.
--
-- Many of the mappings use 'mini.nvim' modules set up in 'plugin/30_mini.lua'.

-- Create a global table with information about Leader groups in certain modes.
-- This is used to provide 'mini.clue' with extra clues.
-- Add an entry if you create a new group.
Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>d', desc = '+Dap' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore/Edit' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>s', desc = '+Session' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },

  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
}

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

local delete_buf_swaps = function()
  local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p')
  if fname == '' then
    vim.notify('No file for current buffer', vim.log.levels.WARN)
    return
  end
  local mangled = fname:gsub('/', '%%')
  local removed = {}
  for dir in vim.gsplit(vim.o.directory, ',', { plain = true }) do
    dir = vim.fn.expand(dir):gsub('/+$', '')
    for _, path in ipairs(vim.fn.glob(dir .. '/' .. mangled .. '.s[a-w][a-z]', false, true)) do
      if vim.fn.delete(path) == 0 then table.insert(removed, path) end
    end
  end
  vim.notify(('Deleted %d swap file(s)'):format(#removed))
end

nmap_leader('ba', '<Cmd>b#<CR>', 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>', 'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>', 'Delete!')
nmap_leader('bs', new_scratch_buffer, 'Scratch')
nmap_leader('bS', delete_buf_swaps, 'Swap files (delete)')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>', 'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ed` - open explorer at current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- - `<Leader>ei` - edit 'init.lua'
-- - `<Leader>el` - open explorer at the plugin install directory
-- - `<Leader>eP` - edit the most recent plan in '~/.claude/plans'
-- - `<Leader>er` - edit the most recent PR review in '~/Documents/pr-reviews'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
  return string.format('<Cmd>edit %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
end
local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
local explore_quickfix = function()
  vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen')
end
local explore_locations = function()
  vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen')
end
local edit_latest_md = function(dir, label)
  return function()
    local files = vim.fn.glob(vim.fn.expand(dir) .. '/*.md', false, true)
    if #files == 0 then
      vim.notify('No ' .. label .. ' found', vim.log.levels.WARN)
      return
    end
    table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)
    vim.cmd('edit ' .. vim.fn.fnameescape(files[1]))
  end
end
local edit_latest_plan      = edit_latest_md('~/.claude/plans',        'Claude plans')
local edit_latest_pr_review = edit_latest_md('~/Documents/pr-reviews', 'PR reviews')
local explore_plugins = function()
  MiniFiles.open(vim.fn.stdpath('data') .. '/site/pack/core/opt')
end

nmap_leader('ec', edit_latest_plan, 'Latest Claude plan')
nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>', 'Directory')
nmap_leader('ef', explore_at_file, 'File directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>', 'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'), 'Keymaps config')
nmap_leader('el', explore_plugins, 'Plugins install dir')
nmap_leader('em', edit_plugin_file('30_mini.lua'), 'MINI config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'), 'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'), 'Plugins config')
nmap_leader('eP', '<Cmd>edit ~/nvim/nushell/lib/install/packages/packages.nu<CR>', 'Packages List')
nmap_leader('eq', explore_quickfix, 'Quickfix list')
nmap_leader('eQ', explore_locations, 'Location list')
nmap_leader('er', edit_latest_pr_review, 'Latest PR review')
nmap_leader('et', '<Cmd>edit ~/Documents/TODO.md<CR>', 'TODO')

-- f is for 'Fuzzy Find'. Common usage:
-- - `<Leader>ff` - find files; for best performance requires `ripgrep`
-- - `<Leader>fg` - find inside files; requires `ripgrep`
-- - `<Leader>fh` - find help tag
-- - `<Leader>fr` - resume latest picker
-- - `<Leader>fv` - all visited paths; requires 'mini.visits'
--
-- All these use 'mini.pick'. See `:h MiniPick-overview` for an overview.
local pick_added_hunks_buf = '<Cmd>Pick git_hunks path="%" scope="staged"<CR>'
local pick_workspace_symbols_live = '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>'
local pick_files_cword = function()
  local word = vim.fn.expand('<cword>')
  vim.schedule(function() MiniPick.set_picker_query({ word }) end)
  vim.cmd('Pick files')
end

nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>', '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>', '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>', 'Added hunks (all)')
nmap_leader('fA', pick_added_hunks_buf, 'Added hunks (buf)')
nmap_leader('fb', '<Cmd>Pick buffers<CR>', 'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>', 'Commits (all)')
nmap_leader('fC', '<Cmd>Pick git_commits path="%"<CR>', 'Commits (buf)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>', 'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>', 'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>', 'Files')
nmap_leader('fF', pick_files_cword, 'Files current word')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>', 'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>', 'Grep current word')
nmap_leader('fh', '<Cmd>Pick help<CR>', 'Help tags')
nmap_leader('fH', '<Cmd>Pick hl_groups<CR>', 'Highlight groups')
nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>', 'Lines (all)')
nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>', 'Lines (buf)')
nmap_leader('fm', '<Cmd>Pick git_hunks<CR>', 'Modified hunks (all)')
nmap_leader('fM', '<Cmd>Pick git_hunks path="%"<CR>', 'Modified hunks (buf)')
nmap_leader('fq', function() require('quickfix').pick_lists() end, 'Quickfix lists')
nmap_leader('fr', '<Cmd>Pick resume<CR>', 'Resume')
nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>', 'References (LSP)')
nmap_leader('fs', pick_workspace_symbols_live, 'Symbols workspace (live)')
nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>', 'Symbols document')
nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>', 'Visit paths (all)')
nmap_leader('fV', '<Cmd>Pick visit_paths<CR>', 'Visit paths (cwd)')
nmap_leader('fw', function() require('workspace').pick() end, 'Workspaces')
nmap_leader("f'", '<Cmd>Pick marks<CR>',     'Marks')
nmap_leader('f"', '<Cmd>Pick registers<CR>', 'Registers')

-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'

nmap_leader('ga', '<Cmd>Git diff --cached<CR>', 'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>', 'Added diff buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>', 'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>', 'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>', 'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>', 'Diff buffer')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>', 'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>', 'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at cursor')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
--
-- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- by an "replace" operator in 'mini.operators' (which is more commonly used).
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>', 'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>', 'Diagnostic popup')
nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>', 'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>', 'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>', 'Lens')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>', 'Rename')
nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>', 'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>', 'Source definition')
nmap_leader('lH', '<Cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })<CR>', 'Toggle inlay hints')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')

xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format selection')

-- m is for 'Map'. Common usage:
-- - `<Leader>mt` - toggle map from 'mini.map' (closed by default)
-- - `<Leader>mf` - focus on the map for fast navigation
-- - `<Leader>ms` - change map's side (if it covers something underneath)
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>', 'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>', 'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>', 'Toggle')

-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>', 'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>', 'Zoom toggle')

-- s is for 'Session'. Common usage:
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sR` - restart Neovim preserving current session
local session_new = 'vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)'

nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>', 'New')
nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>', 'Read')
nmap_leader('sR', '<Cmd>lua MiniSessions.restart()<CR>', 'Restart')
nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>', 'Write current')

-- t is for 'Terminal'
nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>', 'Terminal (vertical)')

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end

nmap_leader('vc', make_pick_core('', 'Core visits (all)'), 'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'), 'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>', 'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>', 'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>', 'Remove label')
-- stylua: ignore end

--- Code Companion
local nvmap_leader = function(suffix, rhs, desc)
  vim.keymap.set({ 'n', 'v' }, '<Leader>' .. suffix, rhs, { desc = desc })
end

local vmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('v', '<Leader>' .. suffix, rhs, { desc = desc })
end

nvmap_leader("aa", "<cmd>CodeCompanionActions<cr>", "CC Actions")
nvmap_leader("at", "<cmd>CodeCompanionChat Toggle<cr>", "CC Toggle")
vmap_leader("aA", "<cmd>CodeCompanionChat Add<cr>", "CC Add")

-- command line motions from :h cmdline.txt
vim.keymap.set('c', '<C-A>', '<Home>')
vim.keymap.set('c', '<C-F>', '<Right>')
vim.keymap.set('c', '<C-B>', '<Left>')

-- <S-Right> ... the name for word motion
vim.keymap.set('c', '<Esc>b', '<S-Left>')
vim.keymap.set('c', '<Esc>f', '<S-Right>')

-- dap
nmap_leader('dc', "<Cmd>DapContinue<CR>", "Continue")
nmap_leader('do', "<Cmd>DapStepOver<CR>", "Step Over")
nmap_leader('di', "<Cmd>DapStepInto<CR>", "Step Into")
nmap_leader('dO', "<Cmd>DapStepOut<CR>", "Step Out")
nmap_leader('db', "<Cmd>DapToggleBreakpoint<CR>", "Toggle Breakpoint")
nmap_leader('dB', "<Cmd>DapClearBreakpoints<CR>", "Clear Breakpoints")
nmap_leader('dl', "<Cmd>lua require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>", "Set Log Point")
nmap_leader('dL', "<Cmd>lua require('dap').run_last()<CR>", "Run Last")
nmap_leader('dr', "<Cmd>DapToggleRepl<CR>", "Toggle Repl")
nmap_leader('dh', "<Cmd>lua require('dap.ui.widgets').hover()<CR>", "Hover")
nmap_leader('dp', "<Cmd>lua require('dap.ui.widgets').preview()<CR>", "Preview")
nmap_leader('df', "<Cmd>lua require('dap.ui.widgets').centered_float(require('dap.ui.widgets').frames)<CR>", "Frames")
nmap_leader('ds', "<Cmd>lua require('dap.ui.widgets').centered_float(require('dap.ui.widgets').scopes)<CR>", "Scopes")
