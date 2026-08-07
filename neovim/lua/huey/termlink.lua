-- Makes OSC 8 hyperlinks in ':terminal' buffers clickable.
--
-- Neovim is the terminal emulator for a ':terminal' buffer, and it does nothing
-- with OSC 8. So a CLI that emits hyperlinks (Claude Code, `rg
-- --hyperlink-format`, `ls --hyperlink`, `eza --hyperlink`) renders the link
-- text but drops the target. This module keeps the target.
--
-- 'TermRequest' delivers each OSC 8 open/close with a buffer-relative cursor
-- position, so the pair brackets an exact byte range -- recorded as an extmark,
-- with no pattern-matching of screen text. That matters beyond tidiness: Claude
-- Code renders a *shortened* path but links the absolute one, so scraping the
-- screen could not recover the target even in principle.
--
-- Claude Code only emits hyperlinks for terminals it recognises, which does not
-- include us; `setup()` sets $FORCE_HYPERLINK to override that check.
--
-- Limitations:
-- * Claude Code only links a tool result's path in its verbose transcript
--   view. The default view collapses it to "Read 1 file", which carries no
--   path and so emits no link. Set `"viewMode": "verbose"` in
--   'config/claude/settings.json' (or run `claude --verbose`).
-- * Claude Code puts no line number in the URI (its `Read 15 lines` suffix is
--   rendered outside the link), so its links open at line 1. Producers that do
--   emit a `#line` fragment jump to it.
-- * Only hyperlinked text is clickable. Paths printed in prose stay inert --
--   the deliberate trade for never guessing wrong.
local HueyTermLink = {}
local H = {}

--- @class TermLinkTarget
--- @field path? string  local file, percent-decoded and absolute
--- @field url? string   non-file URI, handed to `vim.ui.open`
--- @field lnum? integer from a `#L12` / `#12` fragment

--- @class TermLinkOpts
--- @field mouse_key? string|false    default '<LeftMouse>'
--- @field mouse_modes? string[]      default { 't', 'n' }
--- @field cursor_key? string|false   default 'gf'
--- @field force_hyperlink? boolean   set $FORCE_HYPERLINK; default true
--- @field notify? boolean            warn when a click hits no link; default true

local defaults = {
  -- A plain click is safe here: a link is an exact OSC 8 range, not a guess at
  -- what looks like a path, so a click either lands inside one or it does not.
  -- A miss is replayed unmapped, leaving ordinary clicking and drag-selection
  -- untouched.
  --
  -- Ctrl+click is deliberately not bound. Windows Terminal claims that gesture
  -- and never forwards the press -- with raw mouse reporting a single Ctrl+click
  -- emits nothing under '?1000h' and only a release under the '?1002h' Nvim
  -- uses, and "experimental.detectURLs": false does not stop it. Supporting it
  -- meant also binding '<C-LeftRelease>', which is not worth carrying when a
  -- plain click already works everywhere.
  mouse_key = '<LeftMouse>',
  mouse_modes = { 't', 'n' },
  cursor_key = 'gf',
  force_hyperlink = true,
  notify = true,
}

H.opts = defaults
H.ns = vim.api.nvim_create_namespace('HueyTermLink')

--- Half-open OSC 8 sequence per buffer, awaiting its closer.
--- @type table<integer, { uri: string, row: integer, col: integer }>
H.pending = {}

--- @type table<integer, table<integer, { uri: string, text: string }>>
--- bufnr => extmark id => the link's URI and the text it was placed over
H.links = {}

--- Closed links awaiting their text; see `H.flush`.
--- @type table<integer, { uri: string, row: integer, col: integer, end_row: integer, end_col: integer }[]>
H.queued = {}

--- @type table<integer, boolean> buffers with a flush already scheduled
H.flush_scheduled = {}

--- Splits an OSC 8 sequence into its params and URI.
--- The grammar is `OSC 8 ; params ; URI`; params is empty in practice but is
--- not guaranteed to be, and the URI may itself contain ';'.
--- @param sequence string
--- @return string? params
--- @return string? uri empty string on the closing sequence
H.parse_osc8 = function(sequence)
  if type(sequence) ~= 'string' then return nil end
  return sequence:match('^\027%]8;([^;]*);(.*)$')
end

--- @param str string
--- @return string
H.percent_decode = function(str)
  local out = str:gsub(
    '%%(%x%x)',
    function(hex) return string.char(tonumber(hex, 16)) end
  )
  return out
end

--- Turns a URI into something openable.
--- @param uri string
--- @return TermLinkTarget?
H.uri_to_target = function(uri)
  if type(uri) ~= 'string' then return nil end

  local scheme, rest = uri:match('^(%a[%w+.%-]*)://(.*)$')
  if not scheme then return nil end
  if scheme:lower() ~= 'file' then return { url = uri } end

  local body, fragment = rest:match('^([^#]*)#?(.*)$')
  local authority, path = body:match('^([^/]*)(/.*)$')
  if not path then return nil end

  -- A file:// URI naming another host is not ours to open; let the URL handler
  -- decide what to do with it.
  if authority ~= '' and authority:lower() ~= 'localhost' then
    return { url = uri }
  end

  local target = { path = H.percent_decode(path) }
  if fragment ~= '' then target.lnum = tonumber(fragment:match('^L?(%d+)')) end
  return target
end

--- Text currently spanned by an extmark, or nil if the range is unreadable.
--- @param buf integer
--- @param mark integer[] `{ id, row, col }` plus a details table
--- @return string?
H.mark_text = function(buf, mark)
  local details = mark[4]
  local ok, lines = pcall(
    vim.api.nvim_buf_get_text,
    buf,
    mark[2],
    mark[3],
    details.end_row,
    details.end_col,
    {}
  )
  if not ok then return nil end
  return table.concat(lines, '\n')
end

--- @param buf integer
--- @param id integer
H.forget = function(buf, id)
  pcall(vim.api.nvim_buf_del_extmark, buf, H.ns, id)
  if H.links[buf] then H.links[buf][id] = nil end
end

--- Whether `row` currently holds at least `col` bytes.
--- @param buf integer
--- @param row integer
--- @param col integer
--- @return boolean
H.addressable = function(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  return line ~= nil and #line >= col
end

--- @param buf integer
H.schedule_flush = function(buf)
  if H.flush_scheduled[buf] then return end
  H.flush_scheduled[buf] = true
  vim.schedule(function()
    H.flush_scheduled[buf] = nil
    H.flush(buf)
  end)
end

--- Narrows a flush batch to the links the synced buffer actually shows.
---
--- Nvim can process several repaints before syncing the buffer once, and the
--- sync reflects only the last of them -- so every earlier frame's coordinates
--- now point at whatever scrolled into them. Two properties of how a TUI draws
--- separate the surviving frame out:
---
---  * a frame is drawn top-down, so start rows never decrease within one; a row
---    lower than its predecessor means drawing restarted, i.e. a new frame.
---  * a repaint re-emits the same URI, so a URI appearing twice is the same
---    link seen across frames. Only its last position can match the buffer.
---
--- Anything ambiguous is dropped: a missing link costs a click, a link anchored
--- to unrelated text opens the wrong file.
--- @param queue { uri: string, row: integer }[]
--- @return table[]
H.latest_frame = function(queue)
  local first = 1
  for i = 2, #queue do
    if queue[i].row < queue[i - 1].row then first = i end
  end

  local last_of = {}
  for i = first, #queue do
    last_of[queue[i].uri] = i
  end

  local out = {}
  for i = first, #queue do
    if last_of[queue[i].uri] == i then table.insert(out, queue[i]) end
  end
  return out
end

--- Turns queued links into extmarks.
---
--- Driven by the buffer sync that follows the sequences, because a TermRequest
--- reports a position in a screen Nvim has not written yet. Anything not
--- placeable against *this* sync is dropped rather than retried -- a retry is
--- by definition matched against a later frame.
--- @param buf integer
H.flush = function(buf)
  local queue = H.queued[buf]
  H.queued[buf] = nil
  if not queue then return end
  if not vim.api.nvim_buf_is_valid(buf) then return end

  for _, link in ipairs(H.latest_frame(queue)) do
    if
      H.addressable(buf, link.row, link.col)
      and H.addressable(buf, link.end_row, link.end_col)
    then
      -- A redrawn frame re-emits the same link at the same spot; without this
      -- every repaint would leave another mark behind.
      for _, old in
        ipairs(
          vim.api.nvim_buf_get_extmarks(
            buf,
            H.ns,
            { link.row, link.col },
            { link.row, link.col },
            {}
          )
        )
      do
        H.forget(buf, old[1])
      end

      -- Deliberately not `strict = false`: that does not merely tolerate a
      -- range past the end of a line, it clamps it, silently anchoring the
      -- link to the wrong text.
      local id = vim.api.nvim_buf_set_extmark(buf, H.ns, link.row, link.col, {
        end_row = link.end_row,
        end_col = link.end_col,
        invalidate = true,
        undo_restore = false,
      })
      H.links[buf] = H.links[buf] or {}
      -- The text is the staleness key: see `H.link_at`.
      H.links[buf][id] = {
        uri = link.uri,
        text = table.concat(
          vim.api.nvim_buf_get_text(
            buf,
            link.row,
            link.col,
            link.end_row,
            link.end_col,
            {}
          ),
          '\n'
        ),
      }
    end
  end
end

--- @param buf integer
--- @param cursor integer[] (1,0)-indexed, buffer-relative
H.close_link = function(buf, cursor)
  local pending = H.pending[buf]
  H.pending[buf] = nil
  if not pending then return end

  -- The text this range describes has not been synced into the buffer yet, so
  -- the extmark cannot be placed here; `H.flush` does it once it is.
  local queue = H.queued[buf] or {}
  table.insert(queue, {
    uri = pending.uri,
    row = pending.row,
    col = pending.col,
    end_row = cursor[1] - 1,
    end_col = cursor[2],
  })
  H.queued[buf] = queue
end

--- @param ev table 'TermRequest' event
H.on_term_request = function(ev)
  local _, uri = H.parse_osc8(ev.data.sequence)
  -- Not OSC 8: leave it to the OSC 7 / OSC 9;4 handlers in 'huey/term.lua'.
  if not uri then return end

  local cursor = ev.data.cursor
  -- ":h TermRequest": the line may be <= 0 once it has scrolled out of the
  -- buffer, in which case there is nothing left to anchor to.
  if not cursor or cursor[1] <= 0 then
    H.pending[ev.buf] = nil
    return
  end

  if uri == '' then
    H.close_link(ev.buf, cursor)
  else
    -- An unclosed link is abandoned rather than stretched to the next closer.
    H.pending[ev.buf] = { uri = uri, row = cursor[1] - 1, col = cursor[2] }
  end
end

--- URI of the link covering a position, if any.
--- @param buf integer
--- @param row integer 0-based
--- @param col integer 0-based byte offset
--- @return string?
H.link_at = function(buf, row, col)
  local links = H.links[buf]
  if not links then return nil end

  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    H.ns,
    { row, col },
    { row, col },
    -- Marks starting on an earlier row/col still cover this position.
    { overlap = true, details = true }
  )

  local best_id, best_uri = -1, nil

  for _, mark in ipairs(marks) do
    local id = mark[1]
    local link = links[id]
    if link then
      -- Staleness is decided by the text, not by whether the line was
      -- rewritten. Nvim re-syncs terminal lines on every refresh even when
      -- nothing visibly changed, so treating a rewrite as invalidation drops
      -- every link within milliseconds -- while a repaint that really does put
      -- different content here leaves the range intact and must be caught.
      if H.mark_text(buf, mark) == link.text then
        -- Ids increase, so the highest is the most recently registered.
        if id > best_id then
          best_id, best_uri = id, link.uri
        end
      else
        H.forget(buf, id)
      end
    end
  end

  return best_uri
end

--- Puts the file in the window the click came from, replacing the terminal.
--- The terminal buffer is only hidden -- 'hidden' is on, so its job keeps
--- running and `<C-o>` or `:b#` brings it back with its links intact.
--- @param target TermLinkTarget
--- @param win integer
HueyTermLink.open = function(target, win)
  if target.url then return vim.ui.open(target.url) end
  if not vim.api.nvim_win_is_valid(win) then return end

  vim.api.nvim_set_current_win(win)
  vim.cmd("normal! m'") -- jumplist entry, so <C-o> returns to the terminal
  vim.cmd.edit(vim.fn.fnameescape(target.path))

  if target.lnum then
    -- nvim_win_set_cursor errors on a line past the end of the buffer, which a
    -- stale `#line` fragment can easily name.
    local lnum = math.min(target.lnum, vim.api.nvim_buf_line_count(0))
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    vim.cmd('normal! zvzz')
  end
end

--- @param win integer
--- @param row integer 0-based
--- @param col integer 0-based byte offset
--- @return TermLinkTarget?
H.resolve = function(win, row, col)
  local uri = H.link_at(vim.api.nvim_win_get_buf(win), row, col)
  return uri and H.uri_to_target(uri)
end

--- @param win integer
--- @param row integer 0-based
--- @param col integer 0-based byte offset
H.act = function(win, row, col)
  local target = H.resolve(win, row, col)

  if not target then
    if H.opts.notify then vim.notify('No link here', vim.log.levels.WARN) end
    return
  end

  HueyTermLink.open(target, win)
end

--- @return integer? win
--- @return integer? row 0-based
--- @return integer? col 0-based byte offset
H.mouse_pos = function()
  local pos = vim.fn.getmousepos()
  -- 0 => a statusline, a window separator, or outside any window.
  if pos.winid == 0 or pos.line == 0 or pos.column == 0 then return nil end
  -- ":h getmousepos()": `column` is a 1-based *byte* index into the line, not a
  -- screen column. Box-drawing borders are 3 bytes each, so `wincol` would land
  -- somewhere else entirely.
  return pos.winid, pos.line - 1, pos.column - 1
end

HueyTermLink.open_at_mouse = function()
  -- Sampled before anything yields: the pointer can move, and the alternate
  -- screen is repainted continuously.
  local win, row, col = H.mouse_pos()
  local target = win and H.resolve(win, row, col)

  if not target then
    -- Replay the click unmapped. Every outcome that is not "open a link" has to
    -- land here: the mapping is buffer-local to a terminal buffer but fires
    -- wherever the pointer is, so returning early would swallow clicks on the
    -- tabline and statusline (`H.mouse_pos` is nil there, winid == 0) as well
    -- as ordinary clicks and drag-selection inside the terminal.
    local key = H.opts.mouse_key
    if key then vim.api.nvim_feedkeys(vim.keycode(key), 'n', false) end
    return
  end

  vim.cmd.stopinsert()
  vim.schedule(function() HueyTermLink.open(target, win) end)
end

HueyTermLink.open_at_cursor = function()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win) -- {1-based row, 0-based byte col}
  H.act(win, cursor[1] - 1, cursor[2])
end

--- @param buf integer
H.on_term_open = function(buf)
  local opts = H.opts

  -- Queued links are placed from here: this fires once Nvim has written the
  -- screen the TermRequest coordinates referred to. Runs under textlock, so it
  -- only schedules.
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if H.queued[buf] then H.schedule_flush(buf) end
    end,
  })

  if opts.mouse_key then
    vim.keymap.set(opts.mouse_modes, opts.mouse_key, HueyTermLink.open_at_mouse, {
      buffer = buf,
      desc = 'Open link under mouse',
    })
  end

  -- 'n' also covers Terminal-Normal mode (mode() == 'nt'); keymap modes do not
  -- distinguish the two. That is the fallback for a click the 't' map misses:
  -- ":h terminal-input" says an unhandled click drops terminal focus and is
  -- reprocessed as in a normal buffer, which lands here.
  if opts.cursor_key then
    vim.keymap.set('n', opts.cursor_key, HueyTermLink.open_at_cursor, {
      buffer = buf,
      desc = 'Open link under cursor',
    })
  end
end

H.create_autocmds = function()
  local gr = vim.api.nvim_create_augroup('HueyTermLink', {})

  vim.api.nvim_create_autocmd('TermRequest', {
    group = gr,
    desc = 'Record OSC 8 hyperlinks as extmarks',
    callback = H.on_term_request,
  })

  vim.api.nvim_create_autocmd('TermOpen', {
    group = gr,
    desc = 'Map link-opening keys in terminal buffers',
    callback = function(ev) H.on_term_open(ev.buf) end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    group = gr,
    desc = 'Forget links of a wiped terminal',
    callback = function(ev)
      H.pending[ev.buf] = nil
      H.queued[ev.buf] = nil
      H.flush_scheduled[ev.buf] = nil
      H.links[ev.buf] = nil
    end,
  })
end

--- @param opts TermLinkOpts?
HueyTermLink.setup = function(opts)
  H.opts = vim.tbl_deep_extend('force', defaults, opts or {})
  _G.HueyTermLink = HueyTermLink

  -- Claude Code (and anything else using the `supports-hyperlinks` package)
  -- gates OSC 8 on a terminal allowlist we are not on. This overrides it, and
  -- is inherited by every child of this Nvim -- including `rg`, `ls` and `eza`.
  if H.opts.force_hyperlink then vim.env.FORCE_HYPERLINK = '1' end

  H.create_autocmds()

  -- `setup()` runs from `later()`, by which point a terminal may already exist.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == 'terminal' then H.on_term_open(buf) end
  end
end

--- @private exported for 'tests/test_termlink.lua'
HueyTermLink.H = H

return HueyTermLink
