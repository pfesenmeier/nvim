# Share module — implementation plan

Implements the design in `neovim/lua/share/README.md`: a buffer-local `gy`
operator in the quickfix window that yanks the covered qf entries into a
register as markdown.

The earlier `plans/share.md` evaluated the original `<leader>h*` design; the
README has since adopted the operator recommendation. This plan is purely about
how to build the operator now.

## Files to create

```
neovim/lua/share/init.lua          -- M.setup, M.yank, M.operator, formatters
neovim/lua/share/formatters.lua    -- built-in diagnostic / lsp_ref / location
neovim/ftplugin/qf.lua             -- buffer-local gy / gyy / xnoremap gy
neovim/plugin/80_libraries.lua     -- consolidated setup for custom libs
```

`80_libraries.lua` is the new home for `require("share").setup({})` and any
future custom-library wiring (jj, quickfix, servers, etc). Existing per-module
plugin files (`50_floatterm`, `60_remote`, `70_bot`) stay as-is for now;
migrate opportunistically.

`ftplugin/qf.lua` already needs to exist for the sibling `quickfix` plan's
buffer-local `dd` — share's mappings live alongside it. If quickfix lands
first, append; otherwise create.

## `share/init.lua` shape

```lua
local M = {}

local defaults = {
  register = "+",
  keymap   = "gy",         -- false disables ftplugin mapping
  format = {
    dispatch   = nil,      -- (item) -> formatter-name; default below
    formatters = {},       -- merged over built-ins
    wrap       = nil,      -- (body, items) -> string; default returns body
  },
}

local opts  -- set by setup()

function M.setup(user) opts = vim.tbl_deep_extend("force", defaults, user or {}) end
function M.opts() return opts end
```

Built-in formatters live in `share/formatters.lua` for testability:
`diagnostic`, `lsp_ref`, `location`. Each takes the qf item and `opts` (so a
user override can call into the built-in for fallback).

### Default dispatch

```lua
local function default_dispatch(item)
  if item.type and item.type ~= "" then return "diagnostic" end
  if item.user_data and item.user_data.lsp then return "lsp_ref" end
  return "location"
end
```

### Code-excerpt helper

Both default formatters want the source line. Read from the loaded buffer when
`item.bufnr` is valid and loaded, otherwise `vim.fn.readfile(path, "", lnum)`
and take the last line. Cache per-file within a single yank call. Language for
the fenced block: `vim.filetype.match({ buf = bufnr })` or `match({ filename })`.

### `M.yank(items, register)`

1. Resolve register: explicit arg → `vim.v.register` (when not `""`/`'"'`) → `opts.register`.
2. For each item, call `dispatch(item)` → formatter name → format string.
3. Join with `"\n\n"`, run `opts.format.wrap(body, items)`.
4. `vim.fn.setreg(register, body)`.
5. `vim.notify(("Shared %d entr%s → @%s"):format(#items, #items == 1 and "y" or "ies", register))`.

### Operator entrypoint

Pattern (mirrors `mini.operators`):

```lua
function M.operator(motion_type)
  if motion_type == nil then
    vim.o.operatorfunc = "v:lua.require'share'.operator"
    return "g@"
  end
  local s = vim.api.nvim_buf_get_mark(0, "[")[1]
  local e = vim.api.nvim_buf_get_mark(0, "]")[1]
  local qflist = vim.fn.getqflist()
  local slice = {}
  for i = s, e do slice[#slice + 1] = qflist[i] end
  M.yank(slice)
end
```

Visual: `M.visual()` reads `getpos("'<")` / `getpos("'>")` line numbers and
slices `getqflist()` the same way.

## `ftplugin/qf.lua`

```lua
if vim.b.share_loaded then return end
vim.b.share_loaded = true

local key = (require("share").opts() or {}).keymap or "gy"
if key == false then return end

vim.keymap.set("n", key,        function() return require("share").operator() end,
  { buffer = true, expr = true, desc = "Share qf entries (operator)" })
vim.keymap.set("n", key .. key, function() return require("share").operator() .. "_" end,
  { buffer = true, expr = true, desc = "Share current qf entry" })
vim.keymap.set("x", key,        function() require("share").visual() end,
  { buffer = true, desc = "Share selected qf entries" })
```

`key .. "_"` (`gy_`) is the standard trick for `gyy`-on-current-line: `_` is a
linewise motion covering the current line, so the operatorfunc receives
`'[ = '] = .`.

## `plugin/80_libraries.lua`

```lua
require("share").setup({})
-- future: require("jj").setup({}), require("quickfix").setup({}), …
```

## Formatter details

### `diagnostic`

```
- **{severity}** `{rel_path}:{lnum}:{col}` — {text}
  ```{lang}
  {code_line}
  ```
```

`{severity}` ← map `item.type`: `E`→`error`, `W`→`warning`, `I`→`info`,
`N`→`hint`, anything else → lowercase of `item.type`.

### `lsp_ref` / `location`

```
- `{rel_path}:{lnum}`
  ```{lang}
  {code_line}
  ```
```

`rel_path` ← `vim.fn.fnamemodify(name, ":.")` against cwd. Fall back to
`item.module` when `item.bufnr == 0` and the file is unreadable.

## Edge cases worth handling now

- Empty slice (motion outside any qf entry) → notify "no qf entries in range",
  do not clobber the register.
- `item.valid == 0` (qf entries from `:caddexpr` without a file) → emit just
  the `item.text` line, no fence.
- Register `"_"` (blackhole) — respect it: format and `setreg("_", body)` is a
  no-op, so just notify and skip the setreg.
- File too large / unreadable for the excerpt → emit the bullet without the
  fenced block rather than failing the whole yank.

## Skipped on purpose

- No location-list variant. `getloclist(0)` is one extra function; add it only
  if a user actually wants it.
- No permalink formatter (`plans/share.md` mentions `:GBrowse!` as a better
  fit for chat). Out of scope for the qf-entry operator.
- No global keymap. `gy` is buffer-local in qf only — leaves global `y` and
  `gy`-in-other-buffers untouched.

## Test plan

Manual, in this repo:

1. `:vimgrep /function/ neovim/lua/share/*` then `:copen`.
2. `gyj` over two entries → paste from `+`, confirm two bullets + fences.
3. `gyy` on a single entry → one bullet.
4. `V` select 3 entries, `gy` → three bullets.
5. `:lua vim.diagnostic.setqflist()` from a buffer with diagnostics, repeat 1–4.
6. `"agy_` → confirm register `a` populated, `+` untouched.
