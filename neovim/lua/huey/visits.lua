-- Bulk label removal for 'mini.visits'.
--
-- 'mini.visits' decays and prunes ordinary visits on every index write but
-- exempts labeled ones (`:h MiniVisits.gen_normalize.default()`), so a label set
-- only ever grows. The plugin drops a label from one path at a time; this is the
-- missing bulk half.
local HueyVisits = {}
local H = {}

--- Prompt for a label and remove it from every path carrying it.
---
--- @param cwd? string `''` for every project, `nil` for the current one. This is
---   the 'mini.visits' cwd convention, see `:h MiniVisits.remove_label()`.
HueyVisits.clear_label = function(cwd)
  local visits = require('mini.visits')
  local scope = cwd == '' and 'all projects' or 'this project'

  H.prompt_label(visits.list_labels('', cwd), function(label)
    if label == nil or label == '' then return end
    local quoted = vim.inspect(label)

    -- Counts distinct files, while the removal below acts on path-cwd pairs: a
    -- file labeled under two projects is one line here but two index entries.
    local n = #visits.list_paths(cwd, { filter = label })
    if n == 0 then return H.notify(('no %s label in %s'):format(quoted, scope)) end

    local msg = ('Remove %s label from %d path(s) in %s?'):format(quoted, n, scope)
    if vim.fn.confirm(msg, '&No\n&Yes', 1, 'Question') ~= 2 then return end

    visits.remove_label(label, '', cwd)
    -- Persist now, not at VimLeavePre: another running Nvim holds the pre-clear
    -- index and would write it back over this one on exit.
    visits.write_index()
    H.notify(('cleared %s label from %d path(s)'):format(quoted, n))
  end)
end

HueyVisits.setup = function() _G.HueyVisits = HueyVisits end

--- Ask for one of `labels`, reusing the completion mechanism 'mini.visits' uses
--- for its own label prompts. `v:lua` needs the module reachable on the global.
H.prompt_label = function(labels, on_label)
  if #labels == 0 then return H.notify('no labels to clear') end

  HueyVisits._complete = function(arg_lead)
    local has_lead = function(x) return x:find(arg_lead, 1, true) ~= nil end
    return vim.tbl_filter(has_lead, labels)
  end
  local completion = 'customlist,v:lua.HueyVisits._complete'
  vim.ui.input({ prompt = 'Clear label: ', completion = completion }, function(label)
    HueyVisits._complete = nil
    on_label(label)
  end)
end

H.notify = function(msg) vim.notify('visits: ' .. msg, vim.log.levels.INFO) end

--- @private exported for 'tests/test_visits.lua'
HueyVisits.H = H

return HueyVisits
