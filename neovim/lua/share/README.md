# Share

Buffer-local operator for the quickfix window that yanks one or more entries
into a register as pretty-formatted markdown — handy for pasting diagnostics,
grep hits, or LSP references into chat, PRs, or issues.

- Operator works over a motion or visual range of quickfix entries
- accepts any register via the usual `"x` prefix
- Per-source formatters (diagnostics, grep, LSP refs, generic) with sensible defaults
- Each formatter overridable by the user

## Proposed Keymap

Buffer-local in the quickfix window only:

| Keys      | Action                                                      |
| --------- | ----------------------------------------------------------- |
| `gy{motion}` | Yank entries covered by motion (e.g. `gyj`, `gy3j`, `gyG`) |
| `gyy`     | Yank the current entry                                      |
| `gy` (visual) | Yank selected entries                                   |
| `"+gy…`   | Same, but explicit register                                 |

`gy` mirrors `y` semantics, stays buffer-local, and leaves the global `y` untouched.

## Proposed Customization

```lua
require("share").setup({
  register = "+",            -- default register
  keymap = "gy",             -- set to false to skip default mapping
  format = {
    -- pick a formatter by inspecting the qf item; return a formatter name
    dispatch = function(item)
      if item.type ~= "" then return "diagnostic" end
      if item.user_data and item.user_data.lsp then return "lsp_ref" end
      return "location"
    end,
    formatters = {
      diagnostic = function(item) ... end,
      lsp_ref    = function(item) ... end,
      location   = function(item) ... end,
    },
    -- wraps the joined per-item output
    wrap = function(body, items) return body end,
  },
})
```

## Example Output

**Diagnostic** (`item.type = "E"`, `item.text = "undefined variable 'foo'"`):

````markdown
- **error** `lua/share/init.lua:42:8` — undefined variable 'foo'
  ```lua
      local bar = foo + 1
  ```
````

**Code location** (grep / LSP reference):

````markdown
- `lua/share/init.lua:42`
  ```lua
      local bar = foo + 1
  ```
````

Multiple entries are joined with a blank line between them.
