# Custom quickfix shortcuts — evaluation

The `neovim/lua/quickfix/README.md` plan proposes:
- An operator `gK<textobject>` (and visual `gK`) to add to the current quickfix list.
- `<leader>kd` to remove an entry inside the quickfix window.
- `<leader>ka` (new named list), `<leader>kD` (drop list), `<leader>kt` (toggle window).
- `[k` / `]k` / `[K` / `]K` for first/next/previous/last quickfix list (mini.bracketed style).

## Prior art already in this config

- `mini.bracketed` (`plugin/30_mini.lua:421`) already binds `[q`/`]q`/`[Q`/`]Q` to next/previous/first/last quickfix **entry** within the current list. The `[`/`]` pair is taken for entry-axis navigation.
- `<leader>eq` (`plugin/20_keymaps.lua:141`) already toggles the quickfix window.
- Built-in but unbound: `:colder` / `:cnewer` (walk the quickfix list stack), `:chistory` (show stack), `vim.diagnostic.setqflist()`, `:packadd cfilter` → `:Cfilter` / `:Cfilter!` (keep/drop entries by pattern).
- `<leader>k` and `gK` are currently free.

## Per-proposal assessment

### `gK<textobject>` operator (keep)
Genuine gap — there is no built-in or mini equivalent for "append text under a motion to the quickfix list." Implement via `vim.go.operatorfunc` + `vim.fn.setqflist({...}, 'a')` with `bufnr`/`lnum`/`text` from the motion's range. Visual variant straightforward. Reference pattern: `mini.operators`.

### `[k` / `]k` / `[K` / `]K` for list-stack (rename)
Conflicts with mini.bracketed's lower=next/upper=first-last convention on a different axis (entries vs. lists). Reusing the bracket shape for a different meaning is the muscle-memory clobber to avoid. Replace with one of:

- `<leader>k[` / `<leader>k]` / `<leader>k{` / `<leader>k}`
- `<leader>kp` / `<leader>kn` / `<leader>kP` / `<leader>kN`

Underneath, wrap `:colder` / `:cnewer` and `setqflist({}, 'r', { nr = N })`.

### `<leader>kt` toggle window (drop)
Duplicate of existing `<leader>eq`. Either remove it or alias for muscle memory — don't add a second implementation.

### `<leader>kd` remove from list (reuse cfilter)
Try `:packadd cfilter` first — `:Cfilter!/pattern/` removes matching entries, which is the vim-spirit answer. For "delete entry under cursor in the qf window," a buffer-local `dd` in `ftplugin/qf.lua` that calls `setqflist({}, 'r', { items = remaining })` is small and idiomatic.

### `<leader>ka` new named list (keep, but wrap built-in)
Vim already supports list titles: `setqflist({}, ' ', { title = name, items = ... })`, and `:chistory` shows them. Wrap that — don't invent a separate storage. Pair with `<leader>kD` to drop the current list (`setqflist({}, 'f')` to free the stack, or `setqflist({}, 'r', { items = {} })` to empty current).

## Scope recommendation

Build:
1. `gK<motion>` / visual `gK` operator that appends to the current list.
2. `:Qf` / `<leader>ka` to create a new named list (prompt for name).
3. `<leader>k[` / `<leader>k]` (and capital variants) over `:colder` / `:cnewer`.
4. `ftplugin/qf.lua` with buffer-local `dd` to remove the entry under cursor.

Skip / reuse:
- Toggle window — use existing `<leader>eq`.
- Bracket-key navigation `[k`/`]k` — collides with mini.bracketed.
- Pattern-based removal — `:packadd cfilter` + `:Cfilter!` already does it.

## Keymap notes

- `gK` and `<leader>k` are free as of this writing. Re-grep `plugin/20_keymaps.lua` before binding (per the now-deleted keymap-collision feedback rule).
- Add `<leader>k` to `Config.leader_group_clues` in `20_keymaps.lua:52` so mini.clue shows the group.
