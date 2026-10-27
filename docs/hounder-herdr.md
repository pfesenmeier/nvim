# Hounder on herdr-core

Exploration notes for building the Hounder explorer (see
`huey-workspace-explorer.md`) on top of [herdr-core](https://github.com/herdrdev/herdr-core)
(`hc`) instead of inside headless nvim servers.

## What herdr-core is

A Rust daemon ("core") that owns terminals. It draws nothing; clients drive it.

- Terminals outlive their viewer. Closing nvim does not stop an agent.
  `--keep` brings back a shell if the program is lost. Tasks are never re-run.
- Each terminal has an address (`t7`), an optional name, `cwd`, `labels`
  (k=v), a `parent`, and a `status`.
- Status comes only from **OSC 7501** (`idle|working|done|blocked|error`,
  plus `kind`, `progress`, `title`, `msg`). It never guesses from screen text.
- Agent verbs: `send` (paste + enter, holds while you have a draft open),
  `keys`, `interrupt`, `read` (screen + history), `wait` (until a turn ends).
- Agents started inside an hc terminal become its children, and the parent
  gets notes when a child ends or gets stuck.
- Templates (`~/.config/herdr-core/templates/*.md`): a command + role prompt,
  started with `hc run <template> "<task>"`.
- Remote machines over ssh show up in the same list (`box/t3`).
- **API**: JSON-RPC 2.0, one message per line, over a Unix socket
  (`$XDG_RUNTIME_DIR/herdr-core/<session>.sock`) or over stdin/stdout through
  `hc connect`. `hc schema` prints the OpenRPC.
- **Shared docs**: `doc.get` / `doc.set` store opaque JSON (1 MiB max) with
  versioned writes (a stale write fails with `conflict`) and push `doc`
  events to subscribers. API only, no CLI verb.
- **Events**: `events.subscribe` (filter by terminal, parent, labels) gives a
  snapshot, then `created|status|turn|title|labels|foreground|finished|removed`
  notifications with a rising `seq`.

## Why it fits

The Hounder sketch lists these as open problems. hc already solves them:

| Hounder needs | hc gives |
| --- | --- |
| State persists across restarts | Terminals live in the core, not in nvim |
| State shared across nvim sessions | Every nvim is just another client of one core |
| `.config/hounder` state store | `doc.get` / `doc.set`, with conflict detection and change events |
| repo / workspace / agent tree | `labels` on each terminal (`repo=nvim ws=feat-x`) and `events.subscribe {labels}` |
| Agent status in the UI | `status` events, no polling |
| "which harness" option | Templates, one per harness (claude, codex, opencode, pi) |
| Run tests in a separate buffer | `hc run --bg --name test ...` + `:term hc attach test` |

It also replaces parts of `lua/workspace/init.lua`. `WorkspaceBots` makes an RPC
call to every running nvim server once a second. With hc it becomes one
`terminal.list` plus an event stream, and it sees agents whether or not any
nvim is running.

## Shape of the plugin

```
lua/hounder/
  rpc.lua       -- JSON-RPC client over `hc connect` (two jobs: requests, events)
  store.lua     -- in-memory terminal table, applies events by seq, doc cache
  explorer.lua  -- mini.files-style columns: repos | workspaces | agents
  view.lua      -- open/reuse `:term hc attach <addr>` buffers, previews
```

### rpc.lua

The simplest path is running `hc connect` as a job, not opening the socket
directly. It finds the right socket, honours `HC_SESSION`, and works through
ssh unchanged.

Use two connections. In plain mode, once you call `events.subscribe`, that
connection only carries notifications.

```lua
-- one request connection; events get a second one the same way
local job = vim.fn.jobstart({ 'hc', 'connect' }, {
  stdout_buffered = false,
  on_stdout = function(_, lines)
    -- lines arrive split; join partials, then vim.json.decode each full line
    -- route by `id` to pending callbacks, or by `method` ('event', 'missed', 'heartbeat')
  end,
})
local function request(method, params, cb)
  next_id = next_id + 1
  pending[next_id] = cb
  vim.fn.chansend(job, vim.json.encode({ jsonrpc = '2.0', id = next_id, method = method, params = params }) .. '\n')
end
```

Attach streams need framed mode (binary frames, credit flow control). Skip
that. Let nvim's own terminal be the viewer: `:term hc attach t7`. Wiping that
buffer only detaches, so the agent keeps running.

### explorer.lua (mini.files-style sync)

| Pane | Source | Line → |
| --- | --- | --- |
| Repos | `$WORKSPACES` / `doc.get 'hounder'` | `doc.set` on add, remove, or rename |
| Workspaces | `jj workspace list` in the repo + `huey.jj` | `jj workspace add/forget` |
| Agents | `store` filtered by `repo=` and `ws=` labels | see below |

Agent line sync:

- **New line with text**: `terminal.run { line = <template>, cwd = ws_path, labels = { repo, ws, hounder = '1' }, name }`,
  using the text as the task. The template sends it once the agent reports ready.
- **New empty line**: start the harness with no task, as an interactive agent.
  This answers open question 1a, as long as empty lines survive the sync.
- **Deleted line**: `terminal.kill`, then `terminal.rm` (confirm first, same as
  mini.files deletes).
- **Edited text**: set a `title=` label. Don't treat an edit as a new message;
  that would make a stray keystroke send text to an agent.
- **`<CR>` / `l`** on an agent: focus its existing `hc attach` buffer, or open one.
- **Preview**: `terminal.read { lines = N }` into a scratch buffer.
- **Virtual text**: status icon, `progress`, `msg`, `foreground.name`. Reuse
  the icons from `huey/term.lua` and map 7501 states onto them
  (working→moon, blocked→⏸, error→⊘, done→●).

### Tabline / notify

`huey/term.lua` stays for plain `:term` buffers. hc agents feed the same
notify and `nvim_echo` progress path from the `status` events. That covers
agents with no buffer open, which today's tabline can't show.

## The catch: status reporting

hc only knows status a program reports through OSC 7501, and it has no
per-agent integrations (CONTRIBUTING.md says so outright).

- Claude Code emits **OSC 9;4** (the progress sequence `huey/term.lua`
  parses). Third-party release notes say it has also emitted 7501 since
  v2.1.295, and Codex reportedly does too. The installed version is 2.1.318.
  This hasn't been checked against Anthropic's own changelog. **Check it
  first**: run `hc run --bg claude`, then `hc get <t> --json`, and look at
  `reported` and `status`.
- `huey/term.lua` could parse 7501 too. It is richer than 9;4: `blocked` +
  `kind=permission` replaces the guess that state 4 means "waiting".
- If a harness doesn't emit it, the options are:
  1. Claude Code hooks (`UserPromptSubmit` → working, `Notification` /
     permission → blocked, `Stop` → done) that write
     `\e]7501;state=working\e\\` to the agent's tty. Hook stdout goes to
     Claude, so the hook has to write to the controlling tty. Needs a quick test.
  2. A wrapper command in the template that translates 9;4 into 7501. This
     means a pty proxy, which is heavier.
  3. Use `ready: quiet` in templates and live without status. This loses most
     of the value.
- hc sets `TERM_PROGRAM=ghostty` for its programs. Claude Code should then
  emit OSC 8 links without `FORCE_HYPERLINK`, and they pass through
  `hc attach` raw, so `huey/termlink.lua` should keep working in attached
  buffers. Needs a check.

## Build vs buy

nvim already has most of hc's verbs. In a `:term` buffer, nvim is the pty
holder and the terminal emulator, and every OSC sequence reaches `TermRequest`.

| hc feature | nvim equivalent | Effort |
| --- | --- | --- |
| `run` | `jobstart(cmd, { term = true, cwd })` | have it |
| `read` | `nvim_buf_get_lines` on the term buffer | have it |
| `send` | `chansend(job, '\27[200~' .. text .. '\27[201~')`, short pause, then `'\r'` | ~20 lines |
| `keys` / `interrupt` | `chansend(job, '\3')` etc. | trivial |
| 7501 status | parse in the existing `TermRequest` autocmd in `huey/term.lua` | ~40 lines |
| `wait` (turn end) | `User HueyTermStatus` autocmd fired on working → anything else | ~20 lines |
| labels | `b:` variables | have it |
| templates | Lua table: name → cmd + opening prompt | small |
| list across sessions | `workspace.collect()` RPC fan-out | have it |
| shared across UIs | many UIs can `:connect` to one headless server | have it |
| agents driving agents | `$NVIM` is set inside `:term`, so an agent can run `nvim --server $NVIM --remote-expr ...` behind a small wrapper script | medium |
| draft-aware send | check mode + last key time (`vim.on_key`) before sending | small |

What nvim can't do is keep a program alive without nvim. The pty belongs to
the nvim process, so quitting or crashing the server (`:WorkspaceQuit`,
`:WorkspaceStop`, an OOM) sends SIGHUP and the agent dies. hc puts each
terminal in its own holder process, and the holder runs its own terminal
emulator (ghostty-vt). The agent survives, and hc keeps its screen and status
while no one is watching. Neither one survives a reboot or `wsl --shutdown`:
`--keep` brings back a shell, not the agent.

Middle ground for that one gap: wrap the agent in `abduco`/`dtach`
(`:term abduco -A <name> claude`). That's a separate pty holder with no screen
state. OSC sequences pass through while attached, but a detached agent has no
status and no screen until it redraws.

What buying hc costs:

- Another daemon to install and update, on a pre-1.0 "preview" protocol.
- Two terminal emulators: hc's, plus nvim's on top of `hc attach`. The nvim
  buffer only holds what was painted since attach (plus `--history N`).
- Status comes from two places: `TermRequest` while attached, hc events otherwise.
- hc's detach key `Ctrl+\` is also nvim's terminal-mode escape prefix.
  Wiping the buffer detaches too, so you rarely need the key.

What buying hc gives you beyond lifetime: remote machines in the same list,
a parent/child agent CLI that agents already learn from `hc --skill`, and
paste timing, readiness, and draft holds that are already worked out.

## Compared with Rex

[Rex](https://www.superlogical.com/rex/docs/reference/cli) is a terminal
multiplexer: a macOS/iOS app with a Linux/FreeBSD server. Its model is
sessions → windows → blocks, with splits, zoom, and a Lua config. It also
publishes the OSC 7501 spec that hc reads, so status works the same in both.

It is a worse backend for Hounder:

- No documented way to drive a Rex terminal from a plain tty (no `attach`),
  so it can't live in an nvim `:term`. Its viewers are the Rex apps.
- The wire protocol is undocumented. Clients go through `rex api call` or Lua.
- `wait` only waits for exit, not for a turn to end. No parent/child agents,
  no draft-aware send.
- Labels are single names, not k=v. No shared doc store.
- Stopping the server ends every program. Layouts are restored, processes are not.

Things worth borrowing: the spec's rule for mapping 9;4 onto the root record
until the first 7501 report arrives (useful for `huey/term.lua`), and the
`rex skill setup --agent claude` idea of installing a SessionStart hook that
tells the agent where it is running.

## Recommendation

Build on nvim first. The headless per-workspace servers already handle sharing
and survive UI detach. hc's main win is agents outliving their nvim server,
and that only matters if servers actually die while agents are running.

Put the backend behind a small interface (`list`, `run`, `send`, `read`,
`kill`, `on_status`), so the explorer never knows which one it's using. The
mini.files-style explorer is the real work and stays the same either way. If
agents dying with servers starts to hurt, add an hc backend later (see
"Shape of the plugin").

Spike order:

1. Parse OSC 7501 in `huey/term.lua`. Fall back to 9;4 only until the first
   7501 report, per the Rex spec. Fire `User HueyTermStatus`.
2. `huey/herd.lua`: `run`/`send`/`read`/`wait`/labels on term buffers, with
   cross-server listing through `workspace.collect()`.
3. Agents pane only (one column, labels from the current jj workspace).
4. Repos and workspaces columns.
5. Then decide: hc backend, abduco wrapper, or neither.
