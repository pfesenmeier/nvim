# Projects

Picker + commands for swapping the current nvim UI between headless servers
via the 0.12 built-in `:connect`. The lib spawns a server with
`nvim --listen <sock> --headless` on demand and runs `:connect <sock>` from the
TUI.

There is one server per jj workspace of each project, listening on
`<server_dir>/<project>/<workspace>.sock`. The project's own folder is the
`default` workspace, so a project that is not a jj repo has just that one.
Moving between workspaces is a `:connect` to another server, not a `:cd`. A
server is shown and typed as its project name for `default`, and as
`<project>/<workspace>` otherwise (`nvim/feature`).

## Setup

```lua
require("huey.projects").setup({
  -- store = vim.fn.stdpath("data") .. "/projects.json",  -- default
  -- pinned = { { name = "nvim", path = "~/nvim" } },       -- default
  -- server_dir = vim.fn.stdpath("run") .. "/projects",     -- default
  -- workspace_dir = vim.fn.stdpath("data") .. "/workspaces", -- default
  -- agent_cmd = { "claude" },  -- default; the prompt is appended
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
- `<leader>fw` — pick a workspace of any project (MiniPick), `●` when its
  server is running. Confirming spawns the server if needed, then `:connect`s
  the current UI.
- `[w` / `]w` — `:connect` to the server of the previous / next jj workspace of
  this project, `default` first, spawning it if needed. From an nvim that is no
  project server and whose cwd is in no workspace, `]w` goes to the first and
  `[w` to the last. `[W` / `]W` go to the first / last workspace. Counts
  and wrap-around work as in 'mini.bracketed', whose `MiniBracketed.advance()`
  this drives. Note 'mini.bracketed' has no way to
  register a custom target, so the mappings live in `plugin/20_keymaps.lua`
  rather than in its config; its own `window` target was moved to `[s`/`]s` to
  free `w`.
- The current project and workspace are the ones whose socket this server
  listens on, whatever its cwd. An nvim that is no project server (the TUI's
  own) goes by cwd: a project's folder or a workspace under
  `<workspace_dir>/<project>/`.
- `<leader>wq` / `:ProjectQuit` — stop **this** server and land on the next
  running one (project order, then workspace order, wrapping); from an nvim
  that is no project server, the first running one. One `:connect!`, whose bang
  stops the server it detaches from; ordering rules out anything else, since the
  mapping runs *inside* the server being closed. Quits outright when no other
  server is running.
- `:ProjectConnect <name>[/<workspace>]` — same flow as picker confirm.
- `<leader>fB` / `:ProjectBots` — pick a terminal that has a status icon (the
  same OSC 7501 icon the tabline shows, from `huey/term.lua`) in any **running**
  server. Rows are labelled with the server, read live from each one, and
  refresh every second while the picker is open, so they never show a cached status. A terminal whose
  process exits loses its working/blocked/idle icon; done and error stay until the
  buffer is wiped. A running terminal that has reported a status before stays
  listed with an idle `·` after it clears its status with `state=clear`. Each row shows the terminal's title (`b:term_title`, set by
  OSC 0/2) in place of its buffer name, minus a leading state glyph; Claude Code
  titles itself with a short topic summary. Terminals with no useful title fall
  back to the buffer name. Preview shows the buffer's lines as they are in its own
  server; confirming switches that server to the buffer, then `:connect`s to it.
- `:ProjectStop <name>[/<workspace>]` — RPC-quit a workspace's server and
  clean up the socket; a bare project name stops all of the project's servers.
  Unlike `<leader>wq`, this can target a server other than the current one, and
  leaves the UI where it is.

- `<leader>ep` — project explorer (`lua/huey/explorer.lua`), a floating pane
  in the style of 'mini.files'. A project is `●` when any of its servers is
  running. `<CR>` connects to the default workspace of the project under the
  cursor; delete its line and press `=` to drop it from the list, after a
  confirm prompt. Its servers stop, taking their agents with them, but nothing
  on disk is touched. A pinned project and the one this nvim is in stay. `l` opens its jj workspaces in a pane to the right (`default` first,
  `●` when running), and `h` goes back. `<CR>` on a workspace connects to its
  server, starting it if needed. The workspace pane is editable: add a line and press `=`
  to create a workspace by that name, after a confirm prompt. Each one is a
  `jj workspace add` at `<workspace_dir>/<project>/<name>`, outside the repo,
  sharing the parent of the project's working copy. Deleting a line and
  pressing `=` removes that workspace: its server stops, taking its agents with
  it, then `jj workspace forget` and its folder is deleted. `default` and the
  workspace this nvim is in are never removed. Renaming a line deletes the old
  workspace and creates the new one.

  `l` on a workspace opens a third pane: the agent terminals in that
  workspace's server, the same ones `<leader>fB` lists (empty when the server
  is stopped). Each line shows the agent's status icon and what its terminal
  title says it is working on, with the prompt it started with dimmed after it
  once the two differ. A float right of the pane shows the latest output of the
  agent under the cursor, refreshed every second, and is left out when the
  screen has no room. `<CR>` switches that server to the agent's terminal and
  connects to it. Add a line and press `=` to start `agent_cmd` with the line
  as its prompt, after a confirm prompt; it starts the server if needed and
  runs in a new terminal buffer there without changing what that server shows.
  It is listed with its prompt until it reports a status. Deleting a line and
  pressing `=` deletes that agent's terminal buffer, which stops it; `h` goes back.

  `<Tab>` in the project pane opens the agents of every running server in
  place of the workspace pane; in the workspace pane, those of every workspace
  of the project. Each row also names the workspace it runs in. These panes
  span several servers, so they can only stop agents: start them from a single
  workspace's pane. `<Tab>` on the pane it opened from closes it again, and
  `<Tab>` in an agent pane does nothing.

`:detach` (built-in) drops the UI off a project without stopping it.

There is no `home` entry. The TUI's own server is not registered in
`server_dir`, so it is not reachable through this module: connecting to the
project whose path matches the TUI's startup directory spawns a *separate*
headless server for it and leaves the TUI's original session idle in the
background.
