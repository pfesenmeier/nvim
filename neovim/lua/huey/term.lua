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
  local state, value = sequence:match('^\027%]9;4;(%d+);?(%d)$')

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
  fill = unknown amount)
  if state == 4 then return '⏸' end  -- U+23F8 PAUSE — paused
end

H.get_progress = function(bufnr)
end


H.create_autocmds = function()
  local gr = vim.api.nvim_create_augroup("HueyTerm", {})

  vim.api.nvim_create_autocmd({ "TermRequest" }, {
    callback = function(ev)
      local progress = H.parse_progress(ev.data.sequence)
    end
  })
end
-- When a 1-4 event received, set the status
-- When a state 0 received, remove it

-- Provide a method to draw the tab icon
-- in progress         -> U+25D0 (CIRCLE WITH LEFT HALF BLACK)
-- 2 -> error          -> X
-- 3 -> indeterminate  -> ?
-- 4 -> paused/warning -> !

-- When a terminal buffer is entered, clear a done value (0, 100).





HueTerm.setup = function()
  _G.HueyTerm = HueyTerm
end

return HueyTerm
