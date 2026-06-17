local M = {}

function M.class_for(capture)
  return "ts-" .. (capture:gsub("%.", "-"))
end

local function language_available(lang)
  local ok = pcall(vim.treesitter.language.add, lang)
  if ok then return true end
  for _, ext in ipairs({ ".so", ".dylib" }) do
    local found = vim.api.nvim_get_runtime_file("parser/" .. lang .. ext, false)
    if #found > 0 then
      pcall(vim.treesitter.language.add, lang, { path = found[1] })
      return true
    end
  end
  return false
end

function M.tokenize(code, lang)
  if not lang or lang == "" then return nil, {} end
  if not language_available(lang) then return nil, {} end
  local ok_q, query = pcall(vim.treesitter.query.get, lang, "highlights")
  if not ok_q or not query then return nil, {} end
  local parser = vim.treesitter.get_string_parser(code, lang)
  local tree = (parser:parse() or {})[1]
  if not tree then return nil, {} end
  local root = tree:root()

  local n = #code
  local byte_class = {}
  local captures_seen = {}

  for id, node in query:iter_captures(root, code, 0, -1) do
    local name = query.captures[id]
    if name and not name:match("^_") then
      captures_seen[name] = true
      local _, _, sb = node:start()
      local _, _, eb = node:end_()
      if eb > n then eb = n end
      for i = sb + 1, eb do
        byte_class[i] = name
      end
    end
  end

  local spans = {}
  local i = 1
  while i <= n do
    local cls = byte_class[i]
    local j = i
    while j <= n and byte_class[j] == cls do
      j = j + 1
    end
    spans[#spans + 1] = { start = i, stop = j - 1, capture = cls }
    i = j
  end

  return spans, captures_seen
end

return M
