# bot.nvim — claude status + PR review diagnostics

## Context

`plans/bot-review.md` outlines two new capabilities that build on the existing
`bot/` module (queue → claude TUI):

1. **Claude lifecycle status** in the statusline (`idle` / `working` /
   `needs-input`), driven off Claude Code hooks.
2. **PR review feedback as vim diagnostics**, with a `<leader>fp` picker and
   per-diagnostic actions ("chat about this", "dismiss").

Both pieces lean on the existing `nv` → `remote` RPC bridge
(`scripts/nv`, `neovim/lua/remote/init.lua`) — since Claude runs inside the
parent nvim's floatterm, `$NVIM` is always set and hooks can poke nvim
directly. No state file, no fake LSP.

## Code layout — refactor `bot/`

`bot/` currently holds queue + paste-to-TUI logic in one file. New work is
related ("bot-aware nvim integration") but distinct. Split into submodules,
keep one plugin entry point:

```
neovim/lua/bot/
  init.lua       -- setup() orchestrator; shared opts (prefix, get_terminal, open_terminal)
  queue.lua      -- queue_line / queue_visual / edit_queue / send_and_clear (existing)
  terminal.lua   -- paste(buf, content), submit(buf), wait_until_ready (factored from send_payload)
  status.lua     -- state var + set(state) + statusline component + User BotStatusChanged
  review.lua     -- diagnostics from JSON, namespace, code-action picker
```

Not a new plugin — it's tightly coupled to floatterm config in
`plugin/70_bot.lua` and shares `get_terminal`/`open_terminal`.

Refactor `send_payload` (currently `bot/init.lua:97`) into
`terminal.paste(buf, content)` + `terminal.submit(buf)` so `review.lua`'s
"chat about this" can paste without submitting. `queue.lua` keeps existing
behavior by calling both.

Expose a `format_block(path, range, lines, ft, note)` helper (extracted from
the body of `queue_entry`, `bot/init.lua:39`) so review actions can build the
same fenced-code chat payload.

## `scripts/nv` — two new subcommands

```nu
def "main bot-status" [state: string] {  # idle | working | needs-input
  need-nvim
  let s = (vim-str-escape $state)
  let expr = $"v:lua.require'remote'.bot_status\(\"($s)\"\)"
  ^nvim --server $env.NVIM --remote-expr $expr | ignore
}

def "main bot-review" [path: path] {     # absolute path to review JSON
  need-nvim
  let abs = ($path | path expand)
  let expr = (build-execute-expr "RemoteBotReview" [$abs])
  ^nvim --server $env.NVIM --remote-expr $expr | ignore
}
```

## `neovim/lua/remote/init.lua` — two new entry points

```lua
function M.bot_status(state) require("bot.status").set(state) end
function M.bot_review(path)  require("bot.review").load(path)  end
```

Register `:RemoteBotReview`. `bot_status` is called via `--remote-expr`
directly (like `notify`), no Ex command needed.

## `bot/status.lua`

```lua
local M = { state = "idle" }
function M.set(s)
  M.state = s
  vim.api.nvim_exec_autocmds("User", { pattern = "BotStatusChanged" })
end
function M.component()
  if M.state == "idle" then return "" end
  local icon = ({ working = "⏳", ["needs-input"] = "🔔" })[M.state] or ""
  return icon .. " claude"
end
```

Wired into mini.statusline in `plugin/30_mini.lua`, redrawing on
`User BotStatusChanged`.

Caveat: two Claude terms in one nvim share status. Fine for v1.

## `bot/review.lua`

Namespace-scoped diagnostics. JSON shape:

```json
{ "items": [
    { "file": "neovim/lua/bot/init.lua", "line": 42, "end_line": 50,
      "severity": "critical|warn|suggestion", "message": "..." }
] }
```

`load(path)` groups items by buffer, calls `vim.diagnostic.set(ns, bufnr, …)`,
stashes the original item in `user_data`. `vim.diagnostic.reset(ns)` first
so replays don't duplicate.

`code_action()` reads the diagnostic at cursor, shows `vim.ui.select` with
"Chat about this" / "Dismiss". "Chat" builds a `bot.queue.format_block`
payload (file/range/lines/note) and `bot.terminal.paste`s it without submit.

## `config/claude/skills/pr-review/SKILL.md`

Existing human-readable markdown is preserved unchanged in shape — same path,
same sections, markdown path stays the final line of terminal output. Add:

1. JSON sidecar at the same basename (`.json` next to `.md`).
2. If `$NVIM` is set, run `nv bot-review "<abs-json-path>"` after writing.
3. Print the JSON path on the line *before* the final markdown-path line.

## `config/claude/settings.json` — hooks

- `UserPromptSubmit` → `nv bot-status working`
- `Stop` → `nv bot-status idle` (alongside existing bell)
- `Notification` matcher `permission_prompt` → `nv bot-status needs-input`
  (alongside existing bell)

## Keymaps

`<leader>fp` (in `plugin/20_keymaps.lua`, near `<leader>fd`):

```lua
nmap_leader('fp', function()
  require('mini.extra').pickers.diagnostic({
    get_opts = { namespace = vim.api.nvim_create_namespace('bot.review') }
  })
end, 'PR review feedback')
```

`gba` (review action at cursor) registered inside `bot.setup()` alongside
the other `gb*` maps, with a mini.clue entry. Does NOT touch `<leader>la`
(LSP code action, `20_keymaps.lua:216`).

## Verification

- **Status**: open claude floatterm, send a prompt, watch statusline flip
  `idle → working → idle`. Trigger a permission prompt → `needs-input`.
- **Review**: run `/pr-review` on a branch with known issues. Confirm JSON
  sidecar is written. Diagnostics appear; `<leader>fd` lists them; `<leader>fp`
  filters to review-only. `]d`/`[d` navigate. `gba` on a diagnostic →
  "Chat about this" pastes without submitting; "Dismiss" removes it.
- **Replay**: re-run review, confirm old diagnostics are fully replaced.
- **No-nvim path**: run the skill outside nvim, confirm files still written
  and no error on the missing `nv` call.
