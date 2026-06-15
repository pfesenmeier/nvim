# Workspace

Picker + commands for swapping the current nvim UI between per-folder headless
servers via the 0.12 built-in `:connect`. The lib spawns each workspace's
`nvim --listen <sock> --headless` on demand and runs `:connect <sock>` from the
TUI.

## Setup

```lua
require("workspace").setup({
  workspaces = {
    { name = "nvim",   path = vim.fn.expand("~/nvim") },
    { name = "notes",  path = vim.fn.expand("~/notes") },
  },
  -- server_dir = vim.fn.stdpath("run") .. "/workspaces",  -- default
  -- home_name  = "home",                                  -- pinned entry
})
```

## Surface

- `<leader>fw` — pick a workspace (MiniPick). `home` is always pinned first
  and points at the TUI's original server (`v:servername` captured at setup).
  Confirming spawns the server if needed, then `:connect`s the current UI.
- `:WorkspaceConnect <name>` — same flow as picker confirm.
- `:WorkspaceStop <name>` — RPC-quit the workspace's server and clean up the
  socket. Refuses to stop `home`.

`:detach` (built-in) drops the UI off a workspace without stopping it.

## Nice to Have

- Decorate picker rows with the workspace's claude status (new
  `scripts/nv get-claude-status` subcommand that reads `floatterm.get_status`
  per server).
