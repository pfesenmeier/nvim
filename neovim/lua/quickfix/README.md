# Custom Quickfix Shortcuts

Helpers to build and manage quickfix lists without leaving the buffer you're
working in. Module: `require("quickfix")`.

## Keymaps

### Add entries (normal buffer)

| Map           | Action                                                  |
| ------------- | ------------------------------------------------------- |
| `gca<motion>` | Add the motion range as a single qf entry               |
| `gca_`        | Add the current line (the `_` motion is linewise)       |
| `gcaj` / `gcak` | Add the current line + next/prev line                 |
| `gca` (visual) | Add the visual selection                               |

Entries are appended to the current list with full range info
(`lnum`, `col`, `end_lnum`, `end_col`, `text`).

Note: no `gcaa` shortcut — it would shadow `gca` + `a<textobject>`
(e.g. `gcaa(`).

### Manage lists

| Map         | Action                                              |
| ----------- | --------------------------------------------------- |
| `gcn`       | Push a new empty qf list (prompts for title)        |
| `[e` / `]e` | Older / newer list in the qf stack                  |
| `[E` / `]E` | Oldest / newest list in the qf stack                |

### Quickfix window (buffer-local)

| Map  | Action                                  |
| ---- | --------------------------------------- |
| `dd` | Delete the entry under cursor (preserves title + context) |

### Leader

| Map           | Action                          |
| ------------- | ------------------------------- |
| `<leader>eq`  | Toggle quickfix window          |
| `<leader>fq`  | Pick from quickfix list history |
| `<leader>f'`  | Pick marks                      |
| `<leader>f"`  | Pick registers                  |
