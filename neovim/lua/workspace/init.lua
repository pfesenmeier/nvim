local M = {}

local defaults = {
  workspaces = {},  -- list of { name = string, path = string }
  server_dir = vim.fn.stdpath("run") .. "/workspaces",
  home_name  = "home",
}

local opts = defaults
local home_addr = nil

local function sock_for(name)
  return opts.server_dir .. "/" .. name .. ".sock"
end

local function find_ws(name)
  for _, ws in ipairs(opts.workspaces) do
    if ws.name == name then return ws end
  end
end

local function probe(sock)
  if not vim.loop.fs_stat(sock) then return false end
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock, { rpc = true })
  if not ok or chan == 0 then return false end
  pcall(vim.fn.chanclose, chan)
  return true
end

local function bot_status_remote(sock)
  if not vim.loop.fs_stat(sock) then return nil end
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock, { rpc = true })
  if not ok or chan == 0 then return nil end
  local got, icon = pcall(vim.rpcrequest, chan, "nvim_exec_lua",
    "return require('floatterm').get_status('claude')", {})
  pcall(vim.fn.chanclose, chan)
  if got and icon ~= vim.NIL then return icon end
end

function M.bot_status(name)
  if name == opts.home_name then
    return require("floatterm").get_status("claude")
  end
  return bot_status_remote(sock_for(name))
end

function M.status(name)
  if name == opts.home_name then return "running" end
  return probe(sock_for(name)) and "running" or "stopped"
end

local function spawn(ws)
  local sock = sock_for(ws.name)
  vim.fn.jobstart(
    { "nvim", "--listen", sock, "--headless", "--cmd", "cd " .. vim.fn.fnameescape(ws.path) },
    { detach = true }
  )
  if not vim.wait(2000, function() return probe(sock) end, 50) then
    vim.notify(("workspace: timed out waiting for %s"):format(sock), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.connect(name)
  local addr
  if name == opts.home_name then
    if not home_addr or home_addr == "" then
      vim.notify("workspace: no home address captured at setup", vim.log.levels.ERROR)
      return
    end
    addr = home_addr
  else
    local ws = find_ws(name)
    if not ws then
      vim.notify(("workspace: unknown name '%s'"):format(name), vim.log.levels.ERROR)
      return
    end
    addr = sock_for(name)
    if not probe(addr) and not spawn(ws) then return end
  end
  vim.cmd("connect " .. vim.fn.fnameescape(addr))
end

function M.stop(name)
  if name == opts.home_name then
    vim.notify("workspace: refusing to stop home server", vim.log.levels.WARN)
    return
  end
  local sock = sock_for(name)
  if not probe(sock) then
    vim.notify(("workspace: %s is not running"):format(name), vim.log.levels.WARN)
    return
  end
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock, { rpc = true })
  if not ok or chan == 0 then return end
  pcall(vim.rpcnotify, chan, "nvim_command", "qa!")
  pcall(vim.fn.chanclose, chan)
  vim.wait(1000, function() return not vim.loop.fs_stat(sock) end, 50)
  pcall(os.remove, sock)
end

function M.pick()
  local glyph = function(status) return status == "running" and "●" or "○" end
  local row = function(status, name, trailing)
    local bot = M.bot_status(name) or "  "
    return ("%s %s  %-20s  %s"):format(glyph(status), bot, name, trailing)
  end
  local items = {{
    name = opts.home_name,
    text = row("running", opts.home_name, home_addr or "?"),
  }}
  for _, ws in ipairs(opts.workspaces) do
    items[#items + 1] = {
      name = ws.name,
      text = row(M.status(ws.name), ws.name, ws.path),
    }
  end
  MiniPick.start({
    source = {
      name   = "Workspaces",
      items  = items,
      choose = function(item)
        if not item then return end
        vim.schedule(function() M.connect(item.name) end)
      end,
    },
  })
end

function M.current_name()
  local cwd = vim.fn.resolve(vim.fn.getcwd())
  for _, ws in ipairs(opts.workspaces) do
    if vim.fn.resolve(vim.fn.expand(ws.path)) == cwd then
      return ws.name
    end
  end
  return vim.fn.fnamemodify(cwd, ":t")
end

function M.starter_items()
  local items = {}
  for _, ws in ipairs(opts.workspaces) do
    local bot = M.bot_status(ws.name)
    items[#items + 1] = {
      name    = bot and (ws.name .. " " .. bot) or ws.name,
      action  = ("lua require('workspace').connect('%s')"):format(ws.name),
      section = "Workspaces",
    }
  end
  return items
end

local function names()
  local out = { opts.home_name }
  for _, ws in ipairs(opts.workspaces) do out[#out + 1] = ws.name end
  return out
end

local function workspaces_from_env()
  local raw = vim.env.WORKSPACES
  if not raw or raw == "" then return nil end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    vim.notify("workspace: failed to decode $WORKSPACES", vim.log.levels.WARN)
    return nil
  end
  return decoded
end

function M.setup(user)
  user = user or {}
  if not user.workspaces then user.workspaces = workspaces_from_env() end
  opts = vim.tbl_deep_extend("force", defaults, user)
  vim.fn.mkdir(opts.server_dir, "p")
  home_addr = vim.v.servername

  vim.api.nvim_create_user_command("WorkspaceConnect", function(o)
    M.connect(o.args)
  end, {
    nargs    = 1,
    complete = function() return names() end,
    desc     = "Connect UI to a workspace's nvim server (spawn if needed)",
  })

  vim.api.nvim_create_user_command("WorkspaceStop", function(o)
    M.stop(o.args)
  end, {
    nargs    = 1,
    complete = function() return names() end,
    desc     = "Stop a workspace's nvim server",
  })
end

return M
