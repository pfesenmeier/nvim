local M = {}

local ns = vim.api.nvim_create_namespace("bot.review")

function M.namespace() return ns end

local severity_map = {
  critical = vim.diagnostic.severity.ERROR,
  warn     = vim.diagnostic.severity.WARN,
  warning  = vim.diagnostic.severity.WARN,
  suggestion = vim.diagnostic.severity.INFO,
  info     = vim.diagnostic.severity.INFO,
}

local function resolve_buf(file)
  local cwd = vim.fn.getcwd()
  local abs = vim.startswith(file, "/") and file or (cwd .. "/" .. file)
  local bufnr = vim.fn.bufnr(abs)
  if bufnr == -1 then
    -- Load the buffer unlisted so diagnostics attach without forcing a window.
    bufnr = vim.fn.bufadd(abs)
    vim.fn.bufload(bufnr)
  end
  return bufnr
end

function M.load(path)
  local f, err = io.open(path, "r")
  if not f then
    vim.notify("bot.review: cannot open " .. path .. ": " .. (err or "?"), vim.log.levels.ERROR)
    return
  end
  local raw = f:read("*a")
  f:close()

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" or type(data.items) ~= "table" then
    vim.notify("bot.review: invalid JSON at " .. path, vim.log.levels.ERROR)
    return
  end

  vim.diagnostic.reset(ns)

  local by_buf = {}
  for _, item in ipairs(data.items) do
    local bufnr = resolve_buf(item.file)
    by_buf[bufnr] = by_buf[bufnr] or {}
    local lnum = math.max(0, (tonumber(item.line) or 1) - 1)
    local end_lnum = item.end_line and math.max(lnum, item.end_line - 1) or lnum
    table.insert(by_buf[bufnr], {
      lnum = lnum,
      end_lnum = end_lnum,
      col = 0,
      end_col = 0,
      severity = severity_map[item.severity] or vim.diagnostic.severity.INFO,
      source = "bot.review",
      message = item.message or "",
      user_data = { bot_review = item },
    })
  end

  for bufnr, diags in pairs(by_buf) do
    vim.diagnostic.set(ns, bufnr, diags)
  end

  local count = #data.items
  vim.notify(string.format("bot.review: loaded %d finding%s", count, count == 1 and "" or "s"))
end

local function dismiss(buf, d)
  local remaining = {}
  for _, existing in ipairs(vim.diagnostic.get(buf, { namespace = ns })) do
    if not (existing.lnum == d.lnum
      and existing.end_lnum == d.end_lnum
      and existing.message == d.message) then
      table.insert(remaining, existing)
    end
  end
  vim.diagnostic.set(ns, buf, remaining)
end

local function apply_patch(buf, d, suggestion)
  local lines = vim.split(suggestion, "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then table.remove(lines) end
  vim.api.nvim_buf_set_lines(buf, d.lnum, (d.end_lnum or d.lnum) + 1, false, lines)
  dismiss(buf, d)
end

local function send_suggestion_to_chat(buf, d, label, suggestion)
  local lines = vim.api.nvim_buf_get_lines(buf, d.lnum, (d.end_lnum or d.lnum) + 1, false)
  local range = (d.end_lnum and d.end_lnum ~= d.lnum)
    and string.format("%d-%d", d.lnum + 1, d.end_lnum + 1)
    or tostring(d.lnum + 1)
  local ft = vim.bo[buf].filetype
  local block = require("bot.queue").format_block(
    vim.api.nvim_buf_get_name(buf),
    range,
    lines,
    ft,
    d.message
  )
  -- Append the proposed fix as a fenced block so claude can apply it in context.
  local fix = string.format("Proposed fix (%s):\n```%s\n%s\n```\n\n", label, ft, suggestion)
  require("bot").send_to_terminal(block .. fix, { submit = true })
  dismiss(buf, d)
end

function M.code_action()
  local lnum = vim.fn.line(".") - 1
  local diags = vim.diagnostic.get(0, { lnum = lnum, namespace = ns })
  if #diags == 0 then
    vim.notify("bot.review: no review diagnostic at cursor", vim.log.levels.INFO)
    return
  end
  local d = diags[1]
  local item = d.user_data and d.user_data.bot_review or {}

  -- Build the action list: caller-supplied actions first (each with its own
  -- label describing the fix), then the always-present Chat / Dismiss.
  local entries = {}
  if type(item.actions) == "table" then
    for _, a in ipairs(item.actions) do
      if type(a) == "table" and a.label and a.suggestion then
        -- kind: "patch" (default) → direct buffer edit; "prompt" → send to claude.
        local kind = a.kind == "prompt" and "prompt" or "patch"
        table.insert(entries, {
          label = a.label,
          kind = kind,
          suggestion = a.suggestion,
        })
      end
    end
  end
  table.insert(entries, { label = "Chat about this", kind = "chat" })
  table.insert(entries, { label = "Dismiss", kind = "dismiss" })

  vim.ui.select(entries, {
    prompt = "Review action",
    format_item = function(e) return e.label end,
  }, function(choice)
    if not choice then return end
    local buf = vim.api.nvim_get_current_buf()
    if choice.kind == "patch" then
      apply_patch(buf, d, choice.suggestion)
    elseif choice.kind == "prompt" then
      send_suggestion_to_chat(buf, d, choice.label, choice.suggestion)
    elseif choice.kind == "chat" then
      local lines = vim.api.nvim_buf_get_lines(buf, d.lnum, (d.end_lnum or d.lnum) + 1, false)
      local range = (d.end_lnum and d.end_lnum ~= d.lnum)
        and string.format("%d-%d", d.lnum + 1, d.end_lnum + 1)
        or tostring(d.lnum + 1)
      local block = require("bot.queue").format_block(
        vim.api.nvim_buf_get_name(buf),
        range,
        lines,
        vim.bo[buf].filetype,
        d.message
      )
      require("bot").send_to_terminal(block, { submit = false })
    elseif choice.kind == "dismiss" then
      dismiss(buf, d)
    end
  end)
end

return M
