# Share module — evaluation

The `neovim/lua/share/README.md` plan proposes a module that yanks contents + location as a pretty-formatted string for sharing into AI / Slack / Teams, with diagnostics and quickfix as sources, bound under `<leader>h*`.

## Prior art already in this config

- `<leader>aA` (`CodeCompanionChat Add`, `plugin/20_keymaps.lua:297`) adds the visual selection to AI chat with file metadata — the AI side of the use case is already solved.
- `<leader>fd` / `<leader>fD` (`Pick diagnostic`) browse diagnostics; `<leader>ld` (`vim.diagnostic.open_float`) shows detail. None of them put `path:line: msg` on the clipboard.
- `mini.bracketed` provides `[q`/`]q`/`[Q`/`]Q` over quickfix entries; `<leader>eq` toggles the quickfix window.

Real gap: there is no built-in way to get `path:line: text` (or a permalink) onto the system clipboard, formatted for paste.

## More-vim-in-spirit alternatives

1. **GitHub/GitLab permalink** — `:'<,'>GBrowse!` (vim-fugitive), `snacks.gitbrowse`, or `gitlinker.nvim` copy a permalink for the range. For team chat this is usually preferable to a text snippet — link previews unfurl, no stale paste. Suggested bind: `<leader>gy` (git-yank).
2. **`:TOhtml` + clipboard** — built-in. `:'<,'>TOhtml` produces a syntax-highlighted HTML buffer; pipe to `pbcopy -Prefer html` and Slack/Teams rich-paste keeps the colors. Pure vim, no plugin.
3. **Range-aware Ex command** (`:'<,'>Share`) follows the `:write` / `:yank` / `:put` shape. Composes with `:g/pattern/Share`. More vim-spirit than a `<leader>` chord.
4. **`operatorfunc` operator** (e.g. `gy<motion>`) for motion/textobject capture. Reference pattern: `mini.operators` (`gr`, `gs`, `gx`).

## Scope recommendation

Drop the module abstraction. Two helper functions called from a `:Share` range-command:

- `:[range]Share`             — write `path:line: text` for the range to `v:register` (default `+`)
- `:[range]Share diagnostics` — diagnostics in range / buffer
- `:[range]Share qf`          — quickfix entries

No source registry until a third source actually appears.

## Keymap notes

- `<leader>h` is free, but "h" has no mnemonic for share. Prefer the Ex command. If a chord is wanted, `<leader>y` (yank+) or `gY` (operator) are more memorable.
- Drop `<leader>hq` / `<leader>hQ` from the README — overlaps conceptually with existing `<leader>eq` / `<leader>eQ` (quickfix window toggle).
- Per [[feedback-keymaps]] (deleted but worth restating): grep `plugin/20_keymaps.lua` before binding.
