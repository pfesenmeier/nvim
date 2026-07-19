-- module for forwarding terminal progress events to the outer terminal
-- and to append them to bufferline
local HueyTerm = {}
local H = {}

--  ┌───────┬─────────────────┬─────────────────────────────────────────┐
--  │ state │     meaning     │                  value                  │
--  ├───────┼─────────────────┼─────────────────────────────────────────┤
--  │ 0     │ inactive/remove │ ignored, resets to 0                    │
--  ├───────┼─────────────────┼─────────────────────────────────────────┤
--  │ 1     │ in progress     │ 0–100                                   │
--  ├───────┼─────────────────┼─────────────────────────────────────────┤
--  │ 2     │ error           │ 0–100, optional (keeps last if omitted) │
--  ├───────┼─────────────────┼─────────────────────────────────────────┤
--  │ 3     │ indeterminate   │ ignored                                 │
--  ├───────┼─────────────────┼─────────────────────────────────────────┤
--  │ 4     │ paused/warning  │ 0–100, optional                         │
--  └───────┴─────────────────┴─────────────────────────────────────────┘

--- @class Progress
--- @field state? number
--- @field value? number

--- @table <number, Progess> bufnr => progress
--- chanid would technically be the more stable sender identifier
--- but this is what we actually need for the bufline
local bufstatuses = {}

--- Parses an OSC 9;4 progress sequence
--- Matches "\27]9;4;<state>" or "\27]9;4;<state>;<value>".
--- @param sequence string
--- @return Progress?
H.parse_progress = function(sequence)
  local state, value = sequence:match('^\027%]9;4;(%d+);?(%d*)$')

  if not state then
    return nil
  end

  state = tonumber(state)
  if state < 0 or state > 4 then
    return nil
  end

  return {
    state = state,
    value = value ~= '' and tonumber(value) or nil,
  }
end

--- @param progress Progress
--- @return string|nil
H.get_icon = function(progress)
  local state = progress.state
  local value = progress.value

  local moons = { '○', '◔', '◑', '◕', '●' }
  if state == 1 then
    local idx = math.floor((value or 0) / 25 + 0.5)
    idx = math.max(0, math.min(4, idx))
    return moons[idx + 1]
  end

  if state == 2 then return '⊘' end  -- U+2298 CIRCLED DIVISION SLASH — error
  if state == 3 then return '◌' end  -- U+25CC DOTTED CIRCLE — indeterminate (outline, no 
  if state == 4 then return '⏸' end  -- U+23F8 PAUSE — paused
end


---@param buf number
---@param progress Progress
H.notify = function(buf, progress)
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")

  ---@type string, vim.log.levels
  local msg, level

  if progress.state == 1 and progress.value == 100 then
    msg, level = " is done.", vim.log.levels.INFO
  elseif progress.state == 2 then
    msg, level = " has errored.", vim.log.levels.ERROR
  elseif progress.state == 3 then
    msg, level = " has ???.", vim.log.levels.INFO
  elseif progress.state == 4 then
    msg, level = " is waiting.", vim.log.levels.WARN
  end

  if msg then
    vim.notify(name .. msg, level)
  end
end


---@param buf number
---@return string|nil
HueyTerm.get_icon = function(buf)
  local progress = bufstatuses[buf]

  if not progress then return nil end

  return H.get_icon(progress)
end

H.create_autocmds = function()
  local gr = vim.api.nvim_create_augroup("HueyTerm", {})

  vim.api.nvim_create_autocmd({ "TermRequest" }, {
    group = gr,
    desc = "Update tabline when progress event receieved",
    callback = function(ev)
      local progress = H.parse_progress(ev.data.sequence)
      local buf = ev.buf
      if not buf or not progress then return end

      if progress.state == 0 then
        bufstatuses[buf] = nil
      else
        bufstatuses[buf] = progress
      end

      vim.cmd.redrawtabline()

      H.notify(buf, progress)
    end
  })

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = gr,
    desc = "Removes terminal ('done') statuses when enter a buffer",
    callback = function(ev)
      if (vim.bo[ev.buf].buftype ~= 'terminal') then return end
      local progress = bufstatuses[ev.buf]
      if not progress then return end

      -- 1 => "in progress"
      if progress.state ~= 1 or progress.value == 100 then
        bufstatuses[ev.buf] = nil
      end
    end
  })
end

-- 2 error
-- 4 warning/paused
-- 1 in progress
-- 1 w/ 100 value done
-- 3 indeterminate
local sortOrder = { 3, 1, 4, 2 }

---@param first Progress
---@param second Progress
---@return boolean
H.sort_progress = function(first, second)
  if first.state == 1 and second.state == 1 then
    return first.value < second.value
  end

  return sortOrder[first.state] < sortOrder[second.state]
end

--- @return string|nil icon
HueyTerm.get_editor_icon = function()
  local values = vim.tbl_values(bufstatuses)

  table.sort(values, H.sort_progress)

  return values[1]
end

HueyTerm.setup = function()
  _G.HueyTerm = HueyTerm
  H.create_autocmds()
end

return HueyTerm
