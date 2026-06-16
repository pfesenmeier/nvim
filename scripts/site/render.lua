local M = {}

local function escape(s)
  return (s:gsub("[&<>\"']", {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
  }))
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function node_text(node, src)
  return vim.treesitter.get_node_text(node, src)
end

local function child_of_type(node, type_name)
  for child in node:iter_children() do
    if child:type() == type_name then return child end
  end
end

local function heading_level(node)
  for child in node:iter_children() do
    local lvl = child:type():match("^atx_h(%d)_marker$")
    if lvl then return tonumber(lvl) end
  end
  return 1
end

local function walk(node, src, out, state)
  local t = node:type()
  if t == "atx_heading" then
    local level = heading_level(node)
    local inline = child_of_type(node, "inline")
    local body = inline and trim(node_text(inline, src)) or ""
    if level == 1 and not state.title then state.title = body end
    out[#out + 1] = string.format("<h%d>%s</h%d>", level, escape(body), level)
  elseif t == "paragraph" then
    local inline = child_of_type(node, "inline")
    local body = inline and trim(node_text(inline, src)) or trim(node_text(node, src))
    out[#out + 1] = "<p>" .. escape(body) .. "</p>"
  elseif t == "fenced_code_block" then
    local info = child_of_type(node, "info_string")
    local content = child_of_type(node, "code_fence_content")
    local lang = info and trim(node_text(info, src)) or ""
    local code = content and node_text(content, src) or ""
    code = code:gsub("\n$", "")
    out[#out + 1] = string.format(
      '<pre><code class="language-%s">%s</code></pre>',
      escape(lang),
      escape(code)
    )
  else
    for child in node:iter_children() do
      walk(child, src, out, state)
    end
  end
end

local function ensure_parser()
  local ok, err = pcall(vim.treesitter.language.add, "markdown")
  if ok then return end
  local found = vim.api.nvim_get_runtime_file("parser/markdown.so", false)
  if #found == 0 then
    found = vim.api.nvim_get_runtime_file("parser/markdown.dylib", false)
  end
  if #found > 0 then
    vim.treesitter.language.add("markdown", { path = found[1] })
    return
  end
  error("markdown treesitter parser not available: " .. tostring(err))
end

function M.render(src)
  ensure_parser()
  local parser = vim.treesitter.get_string_parser(src, "markdown")
  local tree = parser:parse()[1]
  local out, state = {}, {}
  walk(tree:root(), src, out, state)
  return table.concat(out, "\n"), state.title or "Untitled"
end

return M
