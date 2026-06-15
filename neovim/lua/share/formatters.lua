local M = {}

local severity_map = { E = "error", W = "warning", I = "info", N = "hint" }
local severity_num = { [1] = "error", [2] = "warning", [3] = "info", [4] = "hint" }

local function rel_path(item)
  local name = item.filename or (item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr)) or ""
  if name == "" then return item.module or "" end
  return vim.fn.fnamemodify(name, ":.")
end

local function code_line(item, cache)
  if not item.lnum or item.lnum <= 0 then return nil, nil end
  local bufnr = item.bufnr and item.bufnr > 0 and item.bufnr or nil
  local name = item.filename or (bufnr and vim.api.nvim_buf_get_name(bufnr)) or ""
  local lang
  if bufnr and vim.api.nvim_buf_is_loaded(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, item.lnum - 1, item.lnum, false)
    lang = vim.filetype.match({ buf = bufnr })
    return lines[1], lang
  end
  if name == "" then return nil, nil end
  local lines = cache[name]
  if not lines then
    local ok, read = pcall(vim.fn.readfile, name)
    if not ok then return nil, nil end
    lines = read
    cache[name] = lines
  end
  lang = vim.filetype.match({ filename = name })
  return lines[item.lnum], lang
end

local function fenced(line, lang)
  if not line then return "" end
  return ("\n  ```%s\n  %s\n  ```"):format(lang or "", line)
end

function M.diagnostic(item, _opts, cache)
  local ud = type(item.user_data) == "table" and item.user_data or {}
  local raw = item.text
  if not raw or raw == "" then raw = ud.message end
  raw = raw or ""

  local sev_letter, msg = raw:match("^([EWIN]) │ [^│]* │ (.+)$")
  local sev = severity_map[item.type]
    or (item.type and item.type ~= "" and item.type:lower())
    or severity_map[sev_letter]
    or severity_num[ud.severity]
    or "note"
  if msg then raw = msg end

  local path = rel_path(item)
  local loc = ("%s:%d:%d"):format(path, item.lnum or 0, item.col or 0)
  local text = raw:gsub("^%s+", ""):gsub("%s+$", "")
  local line, lang = code_line(item, cache)
  return ("- **%s** `%s` — %s%s"):format(sev, loc, text, fenced(line, lang))
end

function M.lsp_ref(item, _opts, cache)
  local path = rel_path(item)
  local loc = ("%s:%d"):format(path, item.lnum or 0)
  local line, lang = code_line(item, cache)
  return ("- `%s`%s"):format(loc, fenced(line, lang))
end

M.location = M.lsp_ref

return M
