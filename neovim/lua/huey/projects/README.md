# Projects

Picker + commands for swapping the current nvim UI between per-folder headless
servers via the 0.12 built-in `:connect`. The lib spawns each project's
`nvim --listen <sock> --headless` on demand and runs `:connect <sock>` from the
TUI.

## Setup

```lua
require("huey.projects").setup({
  -- store = vim.fn.stdpath("data") .. "/projects.json",  -- default
  -- pinned = { { name = "nvim", path = "~/nvim" } },       -- default
  -- server_dir = vim.fn.stdpath("run") .. "/projects",     -- default
})
```

The list is `pinned` followed by the entries in `store`, a JSON array of
`{ "name": ..., "path": ... }` that `<leader>pa` appends to. `~/nvim` is always
pinned first. A stored path that is already listed is skipped. The file can be
edited by hand; every server re-reads it when it changes, so a project added in
one server shows up in the others.

## Surface

- `<leader>pa` / `:ProjectAdd [dir]` — pick a folder under home (`fd`, up to 4
  levels deep, skipping hidden folders, `Library`, `node_modules` and anything
  gitignored) and add it as a project named after the folder. A name already in
  use gets its parent folder prefixed (`work-api`). With `dir`, adds that folder
  without a picker.
- `<leader>fw` — pick a project (MiniPick). Confirming spawns the server if
  needed, then `:connect`s the current UI.
- `[w` / `]w` — connect to the previous / next **running** project, skipping
  stopped ones; `[W` / `]W` jump to the first / last running one. Counts and
  wrap-around work as in 'mini.bracketed', whose `MiniBracketed.advance()` this
  drives. Note 'mini.bracketed' has no way to register a custom target, so the
  mappings live in `plugin/20_keymaps.lua` rather than in its config; its own
  `window` target was moved to `[s`/`]s` to free `w`.
- `<leader>wq` / `:ProjectQuit` — stop **this** project's server and land on
  the next running project (`]w` order, wrapping). One `:connect!`, whose bang
  stops the server it detaches from; ordering rules out anything else, since the
  mapping runs *inside* the server being closed. Quits outright when no other
  project is running.
- `:ProjectConnect <name>` — same flow as picker confirm.
- `<leader>fB` / `:ProjectBots` — pick a terminal that has a status icon (the
  same OSC 7501 icon the tabline shows, from `huey/term.lua`) in any **running**
  project. Rows are read live from each server and refresh every second while
  the picker is open, so they never show a cached status. A terminal whose
  process exits loses its working/blocked/idle icon; done and error stay until the
  buffer is wiped. A running terminal that has reported a status before stays
  listed with an idle `·` after it clears its status with `state=clear`. Each row shows the terminal's title (`b:term_title`, set by
  OSC 0/2) in place of its buffer name, minus a leading state glyph; Claude Code
  titles itself with a short topic summary. Terminals with no useful title fall
  back to the buffer name. Preview shows the buffer's lines as they are in its own
  server; confirming switches that server to the buffer, then `:connect`s to it.
- `:ProjectStop <name>` — RPC-quit the project's server and clean up the
  socket. Unlike `<leader>wq`, this can target a project other than the
  current one, and leaves the UI where it is.

`:detach` (built-in) drops the UI off a project without stopping it.

There is no `home` entry. The TUI's own server is not registered in
`server_dir`, so it is not reachable through this module: connecting to the
project whose path matches the TUI's startup directory spawns a *separate*
headless server for it and leaves the TUI's original session idle in the
background.
