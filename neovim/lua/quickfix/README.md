# Custom Quickfix Shortcuts

- Shortcuts to interact with quickfix

## Proposed Keymaps:

### Add to Current List (operator)

normal: gca<textobject>
visual: gca

### Remove from list

- For "delete entry under cursor in the qf window," a buffer-local `dd` in `ftplugin/qf.lua` that calls `setqflist({}, 'r', { items = remaining })` is small and idiomatic.

### Manage Lists

gcA new list (prompt for name)

### Mini bindings

<leader>eq toggle quickfix (already implemented)
<leader>fq explore quickfix lists
mini.bracketed eE for quickfix lists (hint: enumerations)

unrelated but would be nice:
<leader>fm find marks
<leader>fb find buffers
