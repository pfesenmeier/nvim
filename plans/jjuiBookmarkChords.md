# Make `b` a bookmark chord prefix in jjui

## Context

The user has a nushell helper `jjbst-` (defined in `~/.config/nushell/lib/jj/cmds.nu`) that sets a bookmark on `@-` and tracks it — a one-shot "name this revision and track it" combo. They want similar quick bookmark operations available directly in jjui without leaving the TUI.

Today in jjui, `b` opens the built-in bookmark operations picker (`ui.open_bookmarks`). Confirmed user redesign:

- Move the current `b → open_bookmarks` to **`B`**.
- Free up `b` as a **chord prefix** with three new shortcuts, all acting against the **revision under cursor** in the main revisions view:
  - **`bs`** — Set bookmark: prompt for name, `jj bookmark set NAME -r <cursor>` only (no track step).
  - **`ba`** — Advance: prompt for bookmark name, `jj bookmark move NAME --to <cursor>`. **No** `--allow-backwards`; it should error out loud if the cursor is behind.
  - **`bt`** — Track: prompt for name, `jj bookmark track NAME@origin`.

### jjui binding-syntax facts (extracted from `jjui` binary string table)

- Single key: `key = "X"` (existing pattern in `config.toml`).
- Multi-key chord: `seq = ["b", "a"]` — confirmed by error string `[leader] is no longer supported; use sequence bindings via [[bindings]].seq`, and `config.action: opts.key and opts.seq are mutually exclusive`.
- Defaults use the same `[[bindings]]` shape — e.g. `{ key = "esc", action = "ui.cancel", scope = "ui" }`. User config layers on top.
- Cursor revision is reachable in Lua via `context.change_id()` (`types.lua:16`).
- `input{title, prompt}` (`types.lua:71`) gives a blocking text prompt; `jj(...)` (`types.lua:37`) runs sync and returns `output, err`; `revisions.refresh{}` (`types.lua:8`) reloads the log after a write.

## Approach

All edits are confined to **`/home/pfes/nvim/config/jjui/config.toml`** (symlinked to `~/.config/jjui/config.toml`). Append four `[[bindings]]` entries and three `[[actions]]` entries at the bottom of the file, after the existing `copy_checked_files` block.

### Pattern to follow

Match the style already in the file (see `copy_focused_file`, `config.toml:47-67`): triple-quoted Lua, guard with `flash("...")` early-return on nil input, surface errors via `flash({text=..., error=true})`, success flash with a leading `✓`.

### Concrete TOML to append

```toml
# --- Bookmark chord shortcuts (b prefix; B keeps the original picker) ---

[[bindings]]
key = "B"
action = "ui.open_bookmarks"
scope = "revisions"
desc = "Open bookmarks picker (moved from b)"

[[actions]]
name = "bookmark_set_cursor"
lua = '''
  local rev = context.change_id()
  if not rev or rev == "" then
    flash("no revision under cursor")
    return
  end
  local name = input({ title = "Set bookmark", prompt = "name: " })
  if not name or name == "" then return end
  local _, err = jj("bookmark", "set", name, "-r", rev)
  if err then
    flash({ text = "set failed: " .. err, error = true })
    return
  end
  flash("✓ " .. name .. " → " .. rev:sub(1, 8))
  revisions.refresh({})
'''

[[bindings]]
seq = ["b", "s"]
action = "bookmark_set_cursor"
scope = "revisions"
desc = "Set bookmark on cursor revision"

[[actions]]
name = "bookmark_advance_cursor"
lua = '''
  local rev = context.change_id()
  if not rev or rev == "" then
    flash("no revision under cursor")
    return
  end
  local name = input({ title = "Advance bookmark", prompt = "name: " })
  if not name or name == "" then return end
  local _, err = jj("bookmark", "move", name, "--to", rev)
  if err then
    flash({ text = "advance failed: " .. err, error = true })
    return
  end
  flash("✓ " .. name .. " ↦ " .. rev:sub(1, 8))
  revisions.refresh({})
'''

[[bindings]]
seq = ["b", "a"]
action = "bookmark_advance_cursor"
scope = "revisions"
desc = "Advance bookmark to cursor revision (no backwards)"

[[actions]]
name = "bookmark_track_origin"
lua = '''
  local name = input({ title = "Track bookmark", prompt = "name: " })
  if not name or name == "" then return end
  local _, err = jj("bookmark", "track", name .. "@origin")
  if err then
    flash({ text = "track failed: " .. err, error = true })
    return
  end
  flash("✓ tracking " .. name .. "@origin")
  revisions.refresh({})
'''

[[bindings]]
seq = ["b", "t"]
action = "bookmark_track_origin"
scope = "revisions"
desc = "Track NAME@origin"
```

### Notes on what the seq bindings do to the default `b`

When jjui sees any `seq = ["b", ...]` binding in a scope, it will treat `b` as a prefix in that scope (per the `prefixRune` / `resolveSequenceKey` machinery in the binary). The previous single-key `b → ui.open_bookmarks` default should be shadowed automatically. If it still leaks through during verification (timeout-then-fire pattern), add an explicit override that maps single `b` to `ui.cancel` in `revisions` scope, or contact jjui upstream — but try the simple form first.

## Files touched

- `/home/pfes/nvim/config/jjui/config.toml` — append the four bindings + three actions above. No other files change.

## Verification

Restart jjui (`q` to quit, `<leader>tj` to relaunch — config is read on startup).

1. **`B` opens the picker.** Press `B` from the revisions view → bookmarks picker appears, same as `b` did before.
2. **`b` no longer fires alone.** Press `b` and wait. The picker should NOT open. If it does, the default binding is leaking; add an explicit override as noted above.
3. **`bs` — set.** Cursor on a commit without a bookmark, press `b` then `s`, type `test-set`, enter. Expect: flash `✓ test-set → <changeid>`. Confirm via `jj bookmark list test-set` in a shell — local bookmark exists.
4. **`ba` — advance forward.** Move cursor to a descendant of `test-set`, press `b` then `a`, type `test-set`, enter. Expect: flash `✓ test-set ↦ <changeid>`. Confirm with `jj bookmark list test-set`.
5. **`ba` — backwards is an error.** Move cursor to an ancestor of `test-set`, press `b` then `a`, type `test-set`. Expect: red flash `advance failed: ...` mentioning that the move would be backwards. Bookmark unchanged.
6. **`bt` — track.** Press `b` then `t`, type a real remote bookmark name. Expect success flash. Type a fake name → red error flash from jj's stderr.
7. **Cancel paths.** Press `bs` / `ba` / `bt`, then Esc at the prompt. Expect no shell command, no flash spam, picker doesn't open.
8. **No regressions.** Existing `e`, `E`, `y`, `Y` in `revisions.details` still work; other default bindings (`d` for describe, `g` for jumps, etc.) unaffected.
