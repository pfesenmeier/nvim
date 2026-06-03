# Push to TUI: findings

## Summary

- Pushing into a running TUI from outside is **not exotic** — it's literally just writing bytes to the PTY of the `:terminal` job. The Neovim primitive is `vim.api.nvim_chan_send(chan, data)` (or `vim.fn.chansend`) on the channel stored in `vim.bo[term_buf].channel`.
- It *is* lossy/race-prone in one specific way: the TUI must be **ready to read input**. Both CodeCompanion and sidekick.nvim solve this with the same pattern — start the job with `jobstart({term=true})`, poll the buffer until output stabilizes, then drain a queue of pending sends with a small inter-send delay. That's the whole trick.
- Sidekick deliberately uses `nvim_put` instead of `nvim_chan_send` "to better simulate user input" — relevant if the receiving TUI does bracketed-paste detection (Claude Code does); for raw keystrokes you want `chansend`.
- For one-shot intent (open jjui at a revset, prompt Claude with diagnostics), **launching with argv is strictly better than mutating a running session**: `jjui -r '<revset>' <path>` and `claude "<prompt>"` / `claude -p "<prompt>"` both exist. Reserve PTY-injection for the case where you specifically want to interrupt an *already-running* session.
- Recommendation: pull-out (TUI calls `nv` to fetch editor state) remains the cleanest model. Add push-in only where the user's mental model is "from the editor, kick this TUI" — and even then, prefer argv-on-launch over chansend-into-running.

## CodeCompanion's CLI feature

PR [#2836 "feat: new CLI interaction"](https://github.com/olimorris/codecompanion.nvim/pull/2836) (merged) introduced the feature; PR [#2922 "feat(cli): version 2"](https://github.com/olimorris/codecompanion.nvim/pull/2922) added a persistent floating prompt. Docs at [codecompanion.olimorris.dev/usage/cli](https://codecompanion.olimorris.dev/usage/cli).

**API surface:**
- Ex: `:CodeCompanionCLI`, `:CodeCompanionCLI agent=claude_code`, `:CodeCompanionCLI! <prompt>` (the `!` auto-submits).
- Lua: `require("codecompanion").cli(opts_or_string)` where opts include `{ agent, focus, submit, prompt }`. Variables like `#{diagnostics}` are interpolated from editor context before sending.

**Transport** (see [`lua/codecompanion/interactions/cli/providers/terminal.lua`](https://github.com/olimorris/codecompanion.nvim/blob/main/lua/codecompanion/interactions/cli/providers/terminal.lua)): plain Neovim terminal job. The header literally says "Send queue and readiness detection inspired by sidekick.nvim." The send path is:

```lua
self.chan = vim.fn.jobstart(cmd, { term = true, ... })
-- ...later, after _poll_until_ready():
if item.enter then vim.fn.chansend(self.chan, "\r")
else                vim.fn.chansend(self.chan, item.text:gsub("\r\n","\n")) end
```

Readiness = "buffer has >5 non-empty lines and hasn't changed for 500ms." Items are drained from a queue at 100ms intervals so the TUI's input handling doesn't drop characters.

## sidekick.nvim

Repo: [folke/sidekick.nvim](https://github.com/folke/sidekick.nvim). The "CLI" half of the plugin is exactly the same idea, slightly older. Docs: README sections "AI CLI Integration" / "Sending Content".

**API surface:**
- Ex: `:Sidekick cli send msg="{selection}"`, `:Sidekick cli prompt`, `:Sidekick cli toggle`.
- Lua: `require("sidekick.cli").send({ msg = "{this}" })`. Tokens `{this}`, `{file}`, `{selection}`, `{diagnostics}` are expanded from editor context. Per-session handle exposes `t:send("hi!")`.

**Transport** ([`lua/sidekick/cli/terminal.lua`](https://github.com/folke/sidekick.nvim/blob/main/lua/sidekick/cli/terminal.lua)): same `jobstart({ term = true })` + readiness poll + 100ms-spaced queue drain. The interesting twist:

```lua
-- Use nvim_put to send input to the terminal
-- instead of nvim_chan_send to better simulate user input
-- vim.api.nvim_chan_send(self.job, next)
vim.api.nvim_buf_call(self.buf, function()
  vim.api.nvim_put(vim.split(next, "\n", { plain = true }), "c", false, true)
end)
```

`nvim_put` in a terminal buffer routes through Neovim's paste path, which emits bracketed-paste sequences (`ESC [ 200 ~ ... ESC [ 201 ~`). That matters for Claude Code, which treats bracketed-pasted blocks as a single multi-line input rather than line-by-line submissions.

## Mechanism inventory

| Mechanism | What it is | Reliability | Verdict |
|---|---|---|---|
| `nvim_chan_send` / `chansend` on the term channel | Writes raw bytes to the child PTY's stdin. Get the channel from `vim.bo[buf].channel`. | High, *if* you wait for the program to be ready. Special keys via `vim.keycode("<C-c>")`. | Default choice for single keystrokes / control chars / submitting with `"\r"`. |
| `nvim_put` in the terminal buffer | Routes through paste handler -> emits bracketed-paste. | High for multi-line text. | Use when sending a block to a REPL/chat that supports bracketed paste (Claude Code, most modern shells). |
| Launch fresh with argv | `jjui -r '<revset>'`, `claude "<prompt>"`, `claude -p` for one-shot. | Highest — no IPC race. | Preferred whenever the desired state is expressible as flags. |
| OSC escape sequences | Out-of-band protocol over the PTY. | The child process must explicitly parse them; jjui/Claude don't. | Not applicable here. |
| File-watch + signal | Drop a request file, `kill -USR1 pid`. | Requires cooperation from the TUI. | Only if you own the TUI; not free with jjui/Claude. |
| Tmux `send-keys` | When the TUI lives in tmux, not nvim. | Solid. | Irrelevant inside `:terminal`. |
| Claude Code stdin pipe / `-p` / `--append-system-prompt` | `claude` reads piped stdin as context; `-p` is one-shot non-interactive. See [CLI reference](https://code.claude.com/docs/en/cli-reference). | Highest. | Use for *new* prompts; can't reach into an already-running interactive session this way (see [issue #6009](https://github.com/anthropics/claude-code/issues/6009)). |

Pitfalls of `chansend` worth knowing: it writes raw bytes, not key notation — you must `vim.keycode("<CR>")` / `vim.keycode("<C-c>")` for special keys ([Neovim API docs](https://neovim.io/doc/user/api/), [issue #29299](https://github.com/neovim/neovim/issues/29299)). Sending too fast races the TUI's input loop (hence the 100ms queue spacing in both plugins above). And if the terminal is in normal mode, sends still work — they just may not be visible until you re-enter insert.

## When to push vs when to pull

**Pull (TUI -> editor via `nv`/`$NVIM`)** — your existing pattern. Best when:
- The trigger is naturally inside the TUI ("here, while looking at this revision, jump my editor there").
- The editor's state is small and serializable.
- You want a single source of truth (the TUI requests; the editor answers).

**Push (editor -> TUI)** — add when:
- The trigger is naturally inside the editor ("from this buffer, do X over there").
- The TUI doesn't know to ask, or the user shouldn't have to context-switch to ask it.
- For *launching* a TUI with derived state, use argv.
- For *steering an already-running* TUI, use `chansend` / `nvim_put` with the readiness-queue pattern.

Mapping to the two example use cases:

- *"Open all revisions touching this file in jjui"* — **push-on-launch via argv**. Build the revset in Lua (`'files("<path>")'` or similar), then `jjui -r '<revset>' <path>` in the floatterm. If jjui is already open and you want to retarget it, `chansend` the keybind that opens the revset prompt followed by the revset text and `<CR>`; but a fresh spawn is more reliable.
- *"Prompt running Claude with current diagnostics"* — **two flavors**:
  - If no Claude session exists: `claude "<rendered prompt>"` (fresh spawn, argv).
  - If a session is running and the user wants to inject into it: format the prompt, then `nvim_put` (bracketed-paste so Claude sees one logical message), then `chansend(chan, "\r")` to submit. This is the exact recipe CodeCompanion uses with `{ submit = true }`.

## Concrete recommendation for jjui and Claude

- **Build a small `M.send_to_term(buf, text, {submit=bool, paste=bool})` helper** in your own config that mirrors the CodeCompanion/sidekick approach: queue + 100ms drain + readiness poll on first send. Keep it ~50 lines. Both upstreams are MIT/Apache, free to crib from.
- **jjui**: prefer "close the current floatterm jjui and respawn with `-r '<revset>'`". The revset is computed by your existing `nv`-side code (or by Lua directly — you already have the buffer path). One Ex command: `:JjuiFile` -> spawn `jjui -r 'files("<abs path>")'`. Skip injection-into-running unless users complain.
- **Claude**: two commands.
  - `:ClaudeAsk` -> if a Claude floatterm is live, `nvim_put` (bracketed paste) the rendered prompt + `chansend("\r")`. Reuses the open session, preserves conversation context.
  - `:ClaudeAskNew` -> spawn fresh `claude "<prompt>"`.
  - Prompt rendering pulls diagnostics via `vim.diagnostic.get(0)`; reuse the same context-gather you'd write for any other AI plugin.

## Open questions

- Does jjui already accept a *running-process* command channel (a socket / signal-driven file path) — or only argv at launch? If yes, that's a cleaner path than chansend.
- Does Claude Code's interactive REPL respect bracketed paste reliably across versions? Verify with a smoke test before committing to `nvim_put`; otherwise fall back to `chansend` with explicit `\r` between lines.
- Worth checking whether the `nv` CLI should grow a `nv send <session> <text>` subcommand so external scripts (not just nvim itself) can push into the editor's terminals — symmetric with the existing pull direction.
