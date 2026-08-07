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
})
```

The list also comes from `$WORKSPACES` (a JSON array of the same shape) when
`workspaces` is omitted, which is how it is populated in practice.

## Surface

- `<leader>fw` — pick a workspace (MiniPick). Confirming spawns the server if
  needed, then `:connect`s the current UI.
- `[w` / `]w` — connect to the previous / next **running** workspace, skipping
  stopped ones; `[W` / `]W` jump to the first / last running one. Counts and
  wrap-around work as in 'mini.bracketed', whose `MiniBracketed.advance()` this
  drives. Note 'mini.bracketed' has no way to register a custom target, so the
  mappings live in `plugin/20_keymaps.lua` rather than in its config; its own
  `window` target was moved to `[s`/`]s` to free `w`.
- `<leader>wq` / `:WorkspaceQuit` — stop **this** workspace's server and land on
  the next running workspace (`]w` order, wrapping). One `:connect!`, whose bang
  stops the server it detaches from; ordering rules out anything else, since the
  mapping runs *inside* the server being closed. Quits outright when no other
  workspace is running.
- `:WorkspaceConnect <name>` — same flow as picker confirm.
- `:WorkspaceStop <name>` — RPC-quit the workspace's server and clean up the
  socket. Unlike `<leader>wq`, this can target a workspace other than the
  current one, and leaves the UI where it is.

`:detach` (built-in) drops the UI off a workspace without stopping it.

There is no `home` entry. The TUI's own server is not registered in
`server_dir`, so it is not reachable through this module: connecting to the
workspace whose path matches the TUI's startup directory spawns a *separate*
headless server for it and leaves the TUI's original session idle in the
background.

## Nice to Have

- Decorate picker rows with the workspace's claude status (new
  `scripts/nv get-claude-status` subcommand that reads `floatterm.get_status`
  per server).
