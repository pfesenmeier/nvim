local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*)/") or "."

package.path = script_dir .. "/?.lua;" .. package.path

local build = require("build")
local uv = vim.uv

local HOST, PORT = "127.0.0.1", 8000
local DIST = script_dir .. "/dist"

local subscribers = {}

local function log(msg)
  io.write("[serve] " .. msg .. "\n")
  io.flush()
end

local MIME = {
  html = "text/html; charset=utf-8",
  css = "text/css; charset=utf-8",
  js = "text/javascript; charset=utf-8",
  svg = "image/svg+xml",
  png = "image/png",
  jpg = "image/jpeg",
  jpeg = "image/jpeg",
  gif = "image/gif",
  ico = "image/x-icon",
  txt = "text/plain; charset=utf-8",
}

local function mime_for(path)
  local ext = path:match("%.([^./]+)$") or ""
  return MIME[ext:lower()] or "application/octet-stream"
end

local function read_file(path)
  local fd = io.open(path, "rb")
  if not fd then return nil end
  local s = fd:read("*a")
  fd:close()
  return s
end

local function send_response(sock, status, headers, body)
  headers = headers or {}
  body = body or ""
  headers["Content-Length"] = tostring(#body)
  local lines = { "HTTP/1.1 " .. status .. "\r\n" }
  for k, v in pairs(headers) do
    lines[#lines + 1] = k .. ": " .. v .. "\r\n"
  end
  lines[#lines + 1] = "\r\n"
  lines[#lines + 1] = body
  sock:write(table.concat(lines), function()
    sock:shutdown(function()
      if not sock:is_closing() then sock:close() end
    end)
  end)
end

local function send_sse_headers(sock)
  sock:write(
    "HTTP/1.1 200 OK\r\n"
      .. "Content-Type: text/event-stream\r\n"
      .. "Cache-Control: no-cache\r\n"
      .. "Connection: keep-alive\r\n"
      .. "Access-Control-Allow-Origin: *\r\n"
      .. "\r\n"
      .. "retry: 1000\n\n"
  )
end

local function resolve(path)
  path = path:match("^([^?]*)") or path
  if path == "/" then path = "/index.html" end
  if path:find("%.%.", 1, false) then return nil end
  local rel = path:sub(2)
  local p = DIST .. "/" .. rel
  local st = uv.fs_stat(p)
  if st and st.type == "file" then return p end
  local with_html = p .. ".html"
  st = uv.fs_stat(with_html)
  if st and st.type == "file" then return with_html end
  local idx = p .. "/index.html"
  st = uv.fs_stat(idx)
  if st and st.type == "file" then return idx end
  return nil
end

local function handle_http(sock, method, path)
  if method ~= "GET" then
    send_response(sock, "405 Method Not Allowed", { ["Content-Type"] = "text/plain" }, "method not allowed")
    return
  end
  local disk = resolve(path)
  if not disk then
    send_response(sock, "404 Not Found", { ["Content-Type"] = "text/plain" }, "404 not found")
    return
  end
  local body = read_file(disk)
  if not body then
    send_response(sock, "500 Internal Server Error", { ["Content-Type"] = "text/plain" }, "read error")
    return
  end
  send_response(sock, "200 OK", { ["Content-Type"] = mime_for(disk) }, body)
end

local function on_connection(server)
  local client = uv.new_tcp()
  server:accept(client)
  local buf = ""
  local is_sse = false
  client:read_start(function(err, chunk)
    if err or not chunk then
      subscribers[client] = nil
      if not client:is_closing() then client:close() end
      return
    end
    if is_sse then return end
    buf = buf .. chunk
    if not buf:find("\r\n\r\n", 1, true) then return end
    local req_line = buf:match("^([^\r\n]+)") or ""
    local method, path = req_line:match("^(%S+)%s+(%S+)")
    if not method then
      send_response(client, "400 Bad Request", { ["Content-Type"] = "text/plain" }, "bad request")
      return
    end
    local cleaned = (path or ""):match("^([^?]*)") or path
    if cleaned == "/__reload" then
      is_sse = true
      send_sse_headers(client)
      subscribers[client] = true
      return
    end
    handle_http(client, method, path)
  end)
end

local function broadcast(event)
  local msg = "data: " .. event .. "\n\n"
  local dead = {}
  for sock in pairs(subscribers) do
    local ok = pcall(function() sock:write(msg) end)
    if not ok then dead[#dead + 1] = sock end
  end
  for _, sock in ipairs(dead) do
    subscribers[sock] = nil
    if not sock:is_closing() then sock:close() end
  end
end

local function start_watcher()
  local timer = uv.new_timer()
  local pending = false
  local function debounced()
    if pending then return end
    pending = true
    timer:start(
      80,
      0,
      vim.schedule_wrap(function()
        pending = false
        local ok, err = pcall(build.build_all)
        if ok then
          log("rebuilt")
          broadcast("reload")
        else
          io.stderr:write("[serve] build failed: " .. tostring(err) .. "\n")
          broadcast("error")
        end
      end)
    )
  end

  local watchers = {}
  local function watch(path, opts)
    local w = uv.new_fs_event()
    local ok, err = pcall(function()
      w:start(path, opts or {}, function(e)
        if e then return end
        debounced()
      end)
    end)
    if not ok then
      io.stderr:write("[serve] watch failed for " .. path .. ": " .. tostring(err) .. "\n")
    else
      watchers[#watchers + 1] = w
    end
  end

  watch(script_dir .. "/content", { recursive = true })
  watch(script_dir .. "/style.css", {})
  watch(script_dir .. "/template.html", {})
  return watchers
end

local function start_server()
  local server = uv.new_tcp()
  local ok, err = pcall(function() server:bind(HOST, PORT) end)
  if not ok then
    io.stderr:write("bind failed: " .. tostring(err) .. "\n")
    os.exit(1)
  end
  server:listen(128, function(e)
    if e then
      io.stderr:write("listen error: " .. tostring(e) .. "\n")
      return
    end
    on_connection(server)
  end)
  log("serving http://" .. HOST .. ":" .. PORT)
  return server
end

local ok, err = pcall(build.build_all)
if not ok then
  io.stderr:write("initial build failed: " .. tostring(err) .. "\n")
  os.exit(1)
end

start_watcher()
start_server()

while true do
  vim.wait(60000, function() return false end, 100)
end
