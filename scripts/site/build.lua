local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*)/") or "."

package.path = script_dir .. "/?.lua;" .. package.path

local render = require("render")

local M = {}

local function read_file(path)
  local fd = io.open(path, "rb")
  if not fd then return nil end
  local s = fd:read("*a")
  fd:close()
  return s
end

local function write_file(path, content)
  local dir = path:match("(.*)/")
  if dir then vim.fn.mkdir(dir, "p") end
  local fd, err = io.open(path, "wb")
  if not fd then error("cannot write " .. path .. ": " .. tostring(err)) end
  fd:write(content)
  fd:close()
end

local function list_markdown(dir)
  local out = {}
  for name, kind in vim.fs.dir(dir, { depth = 16 }) do
    if kind == "file" and name:match("%.md$") then
      out[#out + 1] = name
    end
  end
  return out
end

local function substitute(template, vars)
  local result = template
  for key, value in pairs(vars) do
    result = result:gsub("{{" .. key .. "}}", function() return value end)
  end
  return result
end

function M.build_all()
  local content_dir = script_dir .. "/content"
  local dist_dir = script_dir .. "/dist"
  vim.fn.mkdir(dist_dir, "p")

  local template = read_file(script_dir .. "/template.html")
  if not template then error("template.html not found at " .. script_dir) end

  local css = read_file(script_dir .. "/style.css")
  if css then write_file(dist_dir .. "/style.css", css) end

  local files = list_markdown(content_dir)
  for _, rel in ipairs(files) do
    local src = read_file(content_dir .. "/" .. rel)
    local body, title = render.render(src)
    local html = substitute(template, { title = title, body = body })
    local out_rel = rel:gsub("%.md$", ".html")
    write_file(dist_dir .. "/" .. out_rel, html)
    io.write("built " .. out_rel .. "\n")
  end
end

if ... == nil then M.build_all() end

return M
